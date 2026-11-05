import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../features/board/data/board_repository.dart';
import '../models/models.dart';
import 'auth_network_image.dart';
import 'takt_ui.dart';

/// Must match backend `attachment_service.MAX_BYTES` and nginx `client_max_body_size`.
const int kMaxAttachmentBytes = 20 * 1024 * 1024;

String formatBytes(int n) {
  if (n < 1024) return '$n Б';
  if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} КБ';
  return '${(n / (1024 * 1024)).toStringAsFixed(1)} МБ';
}

class PendingLocalFile {
  PendingLocalFile({required this.path, required this.name, required this.size, this.isImage = false});

  final String path;
  final String name;
  final int size;
  final bool isImage;
}

class AttachmentPickException implements Exception {
  AttachmentPickException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Native multi-file picker (`FilePicker.pickFiles`). Rejects files over 20 MB.
Future<List<PendingLocalFile>> pickTaskFiles() async {
  final files = await FilePicker.pickFiles();
  if (files.isEmpty) return const [];
  final out = <PendingLocalFile>[];
  for (final f in files) {
    final path = f.path;
    if (path == null || path.isEmpty) continue;
    final size = f.lengthSync() ?? await f.length() ?? 0;
    if (size <= 0) {
      throw AttachmentPickException('«${f.name}» пустой');
    }
    if (size > kMaxAttachmentBytes) {
      throw AttachmentPickException('«${f.name}» больше 20 МБ');
    }
    final ext = (f.extension ?? '').toLowerCase();
    out.add(
      PendingLocalFile(
        path: path,
        name: f.name,
        size: size,
        isImage: RegExp(r'^(jpe?g|png|gif|webp|heic|bmp)$').hasMatch(ext),
      ),
    );
  }
  return out;
}

class PendingFilesSection extends StatelessWidget {
  const PendingFilesSection({
    super.key,
    required this.files,
    required this.onChanged,
  });

  final List<PendingLocalFile> files;
  final ValueChanged<List<PendingLocalFile>> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    return TaktFormField(
      label: 'Файлы',
      bottomGap: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                try {
                  final picked = await pickTaskFiles();
                  if (picked.isEmpty) return;
                  onChanged([...files, ...picked]);
                } on AttachmentPickException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                  }
                }
              },
              icon: const Icon(Icons.attach_file, size: 18),
              label: const Text('Прикрепить'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Можно несколько файлов, до 20 МБ каждый',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ),
          for (var i = 0; i < files.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  if (files[i].isImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(TaktRadii.md),
                      child: Image.file(
                        File(files[i].path),
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: dark ? TaktColors.surface2Dark : TaktColors.surface2,
                        borderRadius: BorderRadius.circular(TaktRadii.md),
                      ),
                      child: Icon(Icons.insert_drive_file_outlined, size: 20, color: muted),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          files[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        Text(formatBytes(files[i].size), style: TextStyle(fontSize: 11, color: muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final next = [...files]..removeAt(i);
                      onChanged(next);
                    },
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class TaskAttachmentsSection extends StatefulWidget {
  const TaskAttachmentsSection({
    super.key,
    required this.taskId,
    required this.attachments,
    this.editable = false,
    this.onChanged,
  });

  final String taskId;
  final List<TaskAttachment> attachments;
  /// Show «Прикрепить» / delete only while editing the task.
  final bool editable;
  final ValueChanged<TaskItem>? onChanged;

  @override
  State<TaskAttachmentsSection> createState() => _TaskAttachmentsSectionState();
}

class _TaskAttachmentsSectionState extends State<TaskAttachmentsSection> {
  bool _busy = false;
  String? _error;

  Future<void> _pickAndUpload() async {
    final board = context.read<BoardRepository>();
    final api = context.read<ApiClient>();
    late final List<PendingLocalFile> picked;
    try {
      picked = await pickTaskFiles();
    } on AttachmentPickException catch (e) {
      if (mounted) setState(() => _error = e.message);
      return;
    }
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Parallel upload — several files at once.
      final results = await Future.wait(
        picked.map(
          (f) => board.uploadAttachment(
            taskId: widget.taskId,
            path: f.path,
            filename: f.name,
          ),
        ),
      );
      if (!mounted) return;
      if (results.isNotEmpty) widget.onChanged?.call(results.last.task);
    } catch (e) {
      if (mounted) {
        setState(() => _error = api.messageFromError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(TaskAttachment att) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить файл?'),
        content: Text(att.filename),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final task = await context.read<BoardRepository>().deleteAttachment(
            taskId: widget.taskId,
            attachmentId: att.id,
          );
      widget.onChanged?.call(task);
    } catch (e) {
      if (mounted) {
        setState(() => _error = context.read<ApiClient>().messageFromError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(TaskAttachment att) async {
    if (att.isImage && (att.previewUrl != null || att.url.isNotEmpty)) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              InteractiveViewer(
                child: AuthNetworkImage(
                  url: att.previewUrl ?? att.url,
                  fit: BoxFit.contain,
                  width: MediaQuery.sizeOf(ctx).width,
                  height: MediaQuery.sizeOf(ctx).height * 0.75,
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Text(
                  att.filename,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }
    try {
      final api = context.read<ApiClient>();
      final bytes = await api.dio.get<List<int>>(
        att.url,
        options: Options(responseType: ResponseType.bytes),
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${att.filename}');
      await file.writeAsBytes(Uint8List.fromList(bytes.data ?? const []), flush: true);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.read<ApiClient>().messageFromError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final hasFiles = widget.attachments.isNotEmpty;
    // View mode with no files — hide the whole block (no «Нет вложений»).
    if (!widget.editable && !hasFiles) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: TaktFieldLabel('Файлы')),
            if (widget.editable)
              TextButton(
                onPressed: _busy ? null : _pickAndUpload,
                child: Text(_busy ? 'Загрузка…' : 'Прикрепить'),
              ),
          ],
        ),
        if (widget.editable)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Можно несколько файлов, до 20 МБ каждый',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ),
        for (final att in widget.attachments)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: dark ? TaktColors.surface2Dark : TaktColors.surface2,
              borderRadius: BorderRadius.circular(TaktRadii.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(TaktRadii.md),
                onTap: () => _open(att),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      if (att.isImage && att.previewUrl != null)
                        AuthNetworkImage(
                          url: att.previewUrl!,
                          width: 48,
                          height: 48,
                          borderRadius: BorderRadius.circular(TaktRadii.md),
                        )
                      else
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          child: Icon(Icons.insert_drive_file_outlined, color: muted),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              att.filename,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            Text(formatBytes(att.sizeBytes), style: TextStyle(fontSize: 11, color: muted)),
                          ],
                        ),
                      ),
                      if (widget.editable)
                        IconButton(
                          onPressed: _busy ? null : () => _remove(att),
                          icon: Icon(Icons.delete_outline, size: 20, color: muted),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_error!, style: TextStyle(color: TaktColors.danger, fontSize: 13)),
          ),
      ],
    );
  }
}

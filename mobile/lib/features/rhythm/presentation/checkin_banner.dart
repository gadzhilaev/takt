import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../board/cubit/board_cubit.dart';
import '../../../shared/widgets/app_icon.dart';
import '../data/rhythm_models.dart';
import '../data/rhythm_repository.dart';

/// Спокойный баннер «Чек-ин на сегодня» (главная, доска, «Мои задачи»).
class CheckinBanner extends StatefulWidget {
  const CheckinBanner({super.key, this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 4)});

  final EdgeInsets padding;

  @override
  State<CheckinBanner> createState() => _CheckinBannerState();
}

class _CheckinBannerState extends State<CheckinBanner> with WidgetsBindingObserver {
  RhythmRepository? _repo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_repo == null) {
      _repo = context.read<RhythmRepository>();
      _refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      await _repo?.loadCurrent();
    } catch (_) {
      /* офлайн — баннер просто не показываем */
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = _repo ?? context.read<RhythmRepository>();
    return ListenableBuilder(
      listenable: Listenable.merge([repo.current, repo.startable]),
      builder: (context, _) {
        final checkins = repo.current.value;
        final text = checkinBannerText(checkins);
        if (text == null) {
          final startId = checkinStartProjectId(
            checkins,
            repo.startable.value,
            currentProjectId: context.read<BoardCubit>().state.project?.id,
          );
          if (startId == null) return const SizedBox.shrink();
          return _StartButton(projectId: startId, padding: widget.padding, onDone: _refresh);
        }
        final dark = Theme.of(context).brightness == Brightness.dark;
        final accent = dark ? TaktColors.accentDark : TaktColors.accent;
        final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
        final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
        return Padding(
          padding: widget.padding,
          child: Material(
            color: dark ? TaktColors.accentSoftDark : TaktColors.accentSoft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(TaktRadii.md),
              side: BorderSide(color: accent.withValues(alpha: 0.35)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(TaktRadii.md),
              onTap: () async {
                await context.push('/checkin');
                _refresh();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    AppIcon(AppIcons.circleCheck, size: 20, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ответьте одним нажатием — задачи обновятся сами',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ответить',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: accent),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Спокойная кнопка «Пройти чек-ин сейчас» — когда сегодняшнего чек-ина ещё нет.
class _StartButton extends StatefulWidget {
  const _StartButton({required this.projectId, required this.padding, required this.onDone});

  final String projectId;
  final EdgeInsets padding;
  final Future<void> Function() onDone;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _busy = false;

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final c = await context.read<RhythmRepository>().start(widget.projectId);
      if (!mounted) return;
      await context.push('/checkin/${c.id}');
      await widget.onDone();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.read<ApiClient>().messageFromError(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? TaktColors.accentDark : TaktColors.accent;
    return Padding(
      padding: widget.padding,
      child: Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: _busy ? null : _start,
          icon: AppIcon(AppIcons.circleCheck, size: 16, color: accent),
          label: Text(_busy ? 'Готовим…' : 'Пройти чек-ин сейчас'),
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            side: BorderSide(color: accent.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TaktRadii.md)),
          ),
        ),
      ),
    );
  }
}

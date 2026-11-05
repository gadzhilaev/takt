import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api_client.dart';
import 'user_avatar.dart';

/// Loads an API image path that requires Bearer auth (attachments / previews).
class AuthNetworkImage extends StatefulWidget {
  const AuthNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  State<AuthNetworkImage> createState() => _AuthNetworkImageState();
}

class _AuthNetworkImageState extends State<AuthNetworkImage> {
  Uint8List? _bytes;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AuthNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _bytes = null;
    });
    try {
      final api = context.read<ApiClient>();
      final resolved = resolveAvatarUrl(widget.url) ?? widget.url;
      final res = await api.dio.get<List<int>>(
        resolved,
        options: Options(responseType: ResponseType.bytes),
      );
      if (!mounted) return;
      setState(() {
        _bytes = Uint8List.fromList(res.data ?? const []);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_loading) {
      child = const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)));
    } else if (_error != null || _bytes == null || _bytes!.isEmpty) {
      child = Icon(Icons.broken_image_outlined, color: Theme.of(context).hintColor);
    } else {
      child = Image.memory(_bytes!, fit: widget.fit, width: widget.width, height: widget.height);
    }
    final framed = SizedBox(width: widget.width, height: widget.height, child: child);
    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: framed);
    }
    return framed;
  }
}

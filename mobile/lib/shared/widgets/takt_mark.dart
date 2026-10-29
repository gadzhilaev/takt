import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Official Takt symbol from `frontend/public/brand/takt-symbol.svg`.
class TaktMark extends StatelessWidget {
  const TaktMark({super.key, this.height = 22, this.size, this.semanticLabel = 'Takt'});

  final double height;
  /// Alias for [height] (legacy call sites).
  final double? size;
  final String? semanticLabel;

  /// Intrinsic symbol aspect ≈ 1055×1226.
  static const aspect = 1055 / 1226;

  @override
  Widget build(BuildContext context) {
    final h = size ?? height;
    final w = h * aspect;
    return SvgPicture.asset(
      'assets/brand/takt-symbol.svg',
      height: h,
      width: w,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      semanticsLabel: semanticLabel,
    );
  }
}

/// Full logo (symbol + wordmark). Swaps asset for dark surfaces.
class TaktLogo extends StatelessWidget {
  const TaktLogo({super.key, this.height = 28});

  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SvgPicture.asset(
      dark ? 'assets/brand/takt-logo-on-dark.svg' : 'assets/brand/takt-logo.svg',
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      semanticsLabel: 'Takt',
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme.dart';

/// Official Takt symbol only (no wordmark) — `takt-symbol.svg`.
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

/// Mobile brand: symbol + UI text «Takt» (not the logo wordmark SVG).
class TaktBrandLockup extends StatelessWidget {
  const TaktBrandLockup({super.key, this.markHeight = 22});

  final double markHeight;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    return Semantics(
      label: 'Takt',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TaktMark(height: markHeight, semanticLabel: null),
          const SizedBox(width: 8),
          Text(
            'Takt',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.35,
              height: 1,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full logo (symbol + wordmark). Prefer [TaktBrandLockup] in app chrome.
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

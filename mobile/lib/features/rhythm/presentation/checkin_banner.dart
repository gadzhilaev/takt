import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
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
    return ValueListenableBuilder<List<Checkin>>(
      valueListenable: repo.current,
      builder: (context, checkins, _) {
        final text = checkinBannerText(checkins);
        if (text == null) return const SizedBox.shrink();
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

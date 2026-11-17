import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/blocked_badge.dart';
import '../../../shared/widgets/takt_app_bar.dart';
import '../../../shared/widgets/takt_ui.dart';
import '../data/digest_models.dart';
import '../data/digest_repository.dart';
import '../../board/cubit/board_cubit.dart';

/// «Сводка»: сверху 4 числа, ниже «Застряло», «Просрочено», «Узкое место», «Сделано», «Ритм».
/// Любая строка ведёт в задачу.
class DigestPage extends StatefulWidget {
  const DigestPage({
    super.key,
    required this.projectId,
    this.period = DigestPeriod.week,
    this.embedded = false,
  });

  final String projectId;
  final DigestPeriod period;

  /// Вкладка внутри проекта: без своей шапки (её рисует оболочка).
  final bool embedded;

  @override
  State<DigestPage> createState() => _DigestPageState();
}

class _DigestPageState extends State<DigestPage> {
  late DigestPeriod _period = widget.period;
  Digest? _digest;
  String? _error;
  bool _loading = true;

  DigestRepository get _repo => context.read<DigestRepository>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = _digest == null;
      _error = null;
    });
    try {
      final d = await _repo.load(widget.projectId, _period);
      if (!mounted) return;
      setState(() {
        _digest = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.read<ApiClient>().messageFromError(e);
      });
    }
  }

  Future<void> _subscribe(bool v) async {
    await _repo.setSubscribed(widget.projectId, v);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final d = _digest;
    final bg = dark ? TaktColors.surface2Dark : TaktColors.surface2;
    final body = _loading
        ? const Center(child: CircularProgressIndicator.adaptive())
        : d == null
        ? TaktEmptyState(title: _error ?? 'Не удалось загрузить сводку')
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _PeriodSwitch(
                  value: _period,
                  dark: dark,
                  onChanged: (p) {
                    setState(() => _period = p);
                    _load();
                  },
                ),
                const SizedBox(height: 12),
                _Numbers(d: d, dark: dark),
                const SizedBox(height: 12),
                _Section(
                  title: 'Застряло',
                  count: d.stuckTasks.length,
                  dark: dark,
                  empty: 'Ничего не застряло.',
                  children: [
                    for (final t in d.stuckTasks)
                      _TaskRow(
                        task: t,
                        dark: dark,
                        meta: digestDaysLabel(t.daysStuck ?? 0),
                        note: [
                          t.reason ?? 'Причина не указана',
                          if (t.blockedBy != null) t.blockedBy!,
                        ].join(' · '),
                      ),
                  ],
                ),
                _Section(
                  title: 'Просрочено и скоро срок',
                  count: d.overdueTasks.length + d.dueSoonTasks.length,
                  dark: dark,
                  empty: 'Просрочек нет, ближайшие 48 часов спокойные.',
                  children: [
                    for (final t in d.overdueTasks)
                      _TaskRow(
                        task: t,
                        dark: dark,
                        meta: 'просрочено',
                        metaDanger: true,
                      ),
                    for (final t in d.dueSoonTasks)
                      _TaskRow(
                        task: t,
                        dark: dark,
                        meta: 'срок в ближайшие 48 ч.',
                      ),
                  ],
                ),
                _Section(
                  title: 'Узкое место',
                  dark: dark,
                  empty: 'За этот период данных о переносах нет.',
                  header: d.bottleneckName == null
                      ? null
                      : 'Дольше всего задачи стоят в «${d.bottleneckName}» — '
                            'в среднем ${formatDigestHours(d.bottleneckHours ?? 0)}',
                  children: [
                    for (final t in d.bottleneckTasks)
                      _TaskRow(
                        task: t,
                        dark: dark,
                        meta:
                            'в столбце ${formatDigestHours(t.hoursInStatus ?? 0)}',
                      ),
                  ],
                ),
                _Section(
                  title: 'Сделано',
                  count: d.doneTasks.length,
                  dark: dark,
                  empty: 'За этот период ничего не закрыто.',
                  children: [
                    for (final t in d.doneTasks) _TaskRow(task: t, dark: dark),
                  ],
                ),
                _Section(
                  title: 'Ритм',
                  dark: dark,
                  empty: d.rhythmEnabled
                      ? 'Чек-инов за этот период ещё не было.'
                      : 'Ежедневный чек-ин выключен — включите его в настройках проекта.',
                  header: d.rhythmTotal == 0
                      ? null
                      : 'Ответы на чек-ин: ${d.rhythmAnswered} из ${d.rhythmTotal} '
                            '(${digestParticipation(d.participation)})',
                  children: [
                    for (final m in d.missed)
                      _PlainRow(
                        text: m.name,
                        meta: 'без ответа: ${m.missed} из ${m.total}',
                        dark: dark,
                      ),
                  ],
                ),
                SwitchListTile.adaptive(
                  value: d.subscribed,
                  onChanged: _subscribe,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Получать сводку в уведомлениях'),
                ),
              ],
            ),
          );
    if (widget.embedded) return ColoredBox(color: bg, child: body);
    return Scaffold(
      backgroundColor: bg,
      appBar: TaktAppBar(
        title: 'Сводка',
        subtitle: d == null
            ? null
            : '${d.projectName} · ${digestPeriodLabel(d.start, d.end)}',
        onBack: () => context.canPop() ? context.pop() : context.go('/board'),
      ),
      body: body,
    );
  }
}

/// Вкладка «Сводка» в нижнем меню проекта. [projectId] из ссылки (push, уведомление)
/// открывает нужный проект; иначе — текущий проект доски.
class DigestTab extends StatefulWidget {
  const DigestTab({super.key, this.projectId, this.period = DigestPeriod.week});

  final String? projectId;
  final DigestPeriod period;

  @override
  State<DigestTab> createState() => _DigestTabState();
}

class _DigestTabState extends State<DigestTab> {
  @override
  void initState() {
    super.initState();
    _ensureProject();
  }

  @override
  void didUpdateWidget(covariant DigestTab old) {
    super.didUpdateWidget(old);
    if (old.projectId != widget.projectId) _ensureProject();
  }

  void _ensureProject() {
    final wanted = widget.projectId;
    if (wanted == null || wanted.isEmpty) return;
    final board = context.read<BoardCubit>();
    if (board.state.project?.id != wanted) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => board.openProject(wanted),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectId = context.select<BoardCubit, String?>(
      (c) => c.state.project?.id,
    );
    if (projectId == null) return const SizedBox.shrink();
    return DigestPage(
      key: ValueKey('digest-$projectId-${widget.period.wire}'),
      projectId: projectId,
      period: widget.period,
      embedded: true,
    );
  }
}

class _PeriodSwitch extends StatelessWidget {
  const _PeriodSwitch({
    required this.value,
    required this.onChanged,
    required this.dark,
  });

  final DigestPeriod value;
  final ValueChanged<DigestPeriod> onChanged;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final accent = dark ? TaktColors.accentDark : TaktColors.accent;
    return SegmentedButton<DigestPeriod>(
      segments: [
        for (final p in DigestPeriod.values)
          ButtonSegment(value: p, label: Text(p.label)),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.selected) ? Colors.white : null,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.selected) ? accent : null,
        ),
      ),
    );
  }
}

class _Numbers extends StatelessWidget {
  const _Numbers({required this.d, required this.dark});

  final Digest d;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        '${d.done}',
        'сделано',
        dark ? TaktColors.successDark : TaktColors.success,
      ),
      ('${d.stuck}', 'застряло', d.stuck > 0 ? blockedColor(dark) : null),
      ('${d.overdue}', 'просрочено', d.overdue > 0 ? TaktColors.urgent : null),
      (digestParticipation(d.participation), 'ответы на чек-ин', null),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: [
        for (final (v, label, color) in items)
          _Card(
            dark: dark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  v,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color:
                        color ??
                        (dark
                            ? TaktColors.foregroundDark
                            : TaktColors.graphite),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: dark ? TaktColors.mutedDark : TaktColors.muted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.dark, required this.child});

  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: dark ? TaktColors.surfaceDark : TaktColors.surface,
      border: Border.all(
        color: dark ? TaktColors.borderDark : TaktColors.border,
      ),
      borderRadius: BorderRadius.circular(TaktRadii.md),
    ),
    child: child,
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.dark,
    required this.children,
    required this.empty,
    this.count,
    this.header,
  });

  final String title;
  final bool dark;
  final List<Widget> children;
  final String empty;
  final int? count;
  final String? header;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final border = dark ? TaktColors.borderDark : TaktColors.border;
    final isEmpty = children.isEmpty && header == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: dark ? TaktColors.surfaceDark : TaktColors.surface,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(TaktRadii.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$count',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ],
              ),
            ),
            Divider(height: 1, color: border),
            if (header != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Text(
                  header!,
                  style: TextStyle(fontSize: 14, height: 1.35, color: fg),
                ),
              ),
            if (isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  empty,
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              ),
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0 || header != null) Divider(height: 1, color: border),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.dark,
    this.meta,
    this.note,
    this.metaDanger = false,
  });

  final DigestTask task;
  final bool dark;
  final String? meta;
  final String? note;
  final bool metaDanger;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final who = task.assignees.join(', ');
    return InkWell(
      onTap: () => context.push('/task/${task.taskId}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: fg,
                    ),
                  ),
                  if (meta != null || who.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        style: TextStyle(fontSize: 12, color: muted),
                        children: [
                          if (meta != null)
                            TextSpan(
                              text: meta,
                              style: metaDanger
                                  ? const TextStyle(color: TaktColors.urgent)
                                  : null,
                            ),
                          if (meta != null && who.isNotEmpty)
                            const TextSpan(text: ' · '),
                          if (who.isNotEmpty) TextSpan(text: who),
                        ],
                      ),
                    ),
                  ],
                  if (note != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: blockedColor(dark), width: 2),
                        ),
                      ),
                      child: Text(
                        note!,
                        style: TextStyle(fontSize: 12, color: fg),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            AppIcon(AppIcons.chevronRight, size: 16, color: muted),
          ],
        ),
      ),
    );
  }
}

class _PlainRow extends StatelessWidget {
  const _PlainRow({required this.text, required this.meta, required this.dark});

  final String text;
  final String meta;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontSize: 14, color: fg),
          children: [
            TextSpan(text: text),
            TextSpan(
              text: ' — $meta',
              style: TextStyle(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

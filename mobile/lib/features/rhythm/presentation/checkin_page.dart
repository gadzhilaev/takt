import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/takt_app_bar.dart';
import '../../../shared/widgets/takt_ui.dart';
import '../../board/cubit/board_cubit.dart';
import '../data/rhythm_models.dart';
import '../data/rhythm_repository.dart';

/// Цвета ответов: спокойные, но различимые в light/dark.
Color answerColor(CheckinAnswer a, bool dark) {
  switch (a) {
    case CheckinAnswer.done:
      return dark ? TaktColors.successDark : TaktColors.success;
    case CheckinAnswer.inProgress:
      return dark ? TaktColors.accentDark : TaktColors.accent;
    case CheckinAnswer.blocked:
      return dark ? const Color(0xFFE0A146) : TaktColors.important;
  }
}

String _answerIcon(CheckinAnswer a) => switch (a) {
      CheckinAnswer.done => AppIcons.circleCheck,
      CheckinAnswer.inProgress => AppIcons.status,
      CheckinAnswer.blocked => AppIcons.alert,
    };

const _priorityLabels = {
  'urgent': 'Срочно',
  'high': 'Важно',
  'medium': 'Обычная',
  'low': 'Низкая',
};

/// Экран чек-ина: по задаче — одна из трёх крупных кнопок; «Застрял» — короткая причина.
/// [checkinId] — из push; без него открывается первый неотвеченный на сегодня.
class CheckinPage extends StatefulWidget {
  const CheckinPage({super.key, this.checkinId});

  final String? checkinId;

  @override
  State<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends State<CheckinPage> {
  Checkin? _checkin;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, CheckinChoice> _choices = {};
  final _reasons = <String, TextEditingController>{};

  RhythmRepository get _repo => context.read<RhythmRepository>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in _reasons.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Checkin? c;
      if (widget.checkinId != null) {
        c = await _repo.get(widget.checkinId!);
      } else {
        final list = await _repo.loadCurrent();
        c = list.where((x) => x.isPending).firstOrNull ?? list.firstOrNull;
      }
      if (!mounted) return;
      setState(() {
        _checkin = c;
        _choices = c == null ? {} : initialChoices(c);
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

  TextEditingController _reasonFor(String taskId) => _reasons.putIfAbsent(
        taskId,
        () => TextEditingController(text: _choices[taskId]?.reason ?? ''),
      );

  void _pick(String taskId, CheckinAnswer a) {
    setState(() {
      _choices = {
        ..._choices,
        taskId: CheckinChoice(a, a == CheckinAnswer.blocked ? _reasonFor(taskId).text : null),
      };
    });
  }

  Future<void> _submit() async {
    final c = _checkin;
    if (c == null) return;
    // Причины берём из полей ввода в момент отправки.
    final choices = {
      for (final e in _choices.entries)
        e.key: e.value.answer == CheckinAnswer.blocked
            ? CheckinChoice(e.value.answer, _reasons[e.key]?.text)
            : e.value,
    };
    final answers = buildCheckinAnswers(c, choices);
    if (answers.isEmpty) {
      _close();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.answer(c.id, answers);
      if (!mounted) return;
      final board = context.read<BoardCubit>();
      if (board.state.project?.id == c.projectId) {
        // Тихо: задачи уже обновил сервер, подтягиваем без спиннера.
        board.refreshBoard();
      }
      _close();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = context.read<ApiClient>().messageFromError(e);
      });
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/projects');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final c = _checkin;
    final answered = c == null
        ? 0
        : c.items.where((i) => _choices.containsKey(i.taskId)).length;
    return Scaffold(
      appBar: TaktAppBar(
        title: 'Чек-ин на сегодня',
        subtitle: c?.projectName,
        onBack: _close,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : c == null
              ? TaktEmptyState(
                  icon: AppIcons.circleCheck,
                  title: _error ?? 'На сегодня всё',
                  subtitle: _error == null
                      ? 'Новых вопросов по задачам нет. Чек-ин придёт в рабочий день.'
                      : null,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: c.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ItemCard(
                    item: c.items[i],
                    choice: _choices[c.items[i].taskId],
                    reason: _reasonFor(c.items[i].taskId),
                    busy: _busy,
                    dark: dark,
                    onPick: (a) => _pick(c.items[i].taskId, a),
                  ),
                ),
      bottomNavigationBar: c == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_error!, style: const TextStyle(color: TaktColors.danger)),
                      ),
                    Row(
                      children: [
                        Text(
                          '$answered из ${c.items.length}',
                          style: TextStyle(fontSize: 13, color: muted),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TaktButton(
                            label: _busy ? 'Сохраняем…' : 'Готово',
                            expand: true,
                            onPressed: _busy ? null : _submit,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.choice,
    required this.reason,
    required this.busy,
    required this.dark,
    required this.onPick,
  });

  final CheckinItem item;
  final CheckinChoice? choice;
  final TextEditingController reason;
  final bool busy;
  final bool dark;
  final ValueChanged<CheckinAnswer> onPick;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    final border = dark ? TaktColors.borderDark : TaktColors.border;
    final meta = [
      _priorityLabels[item.priority] ?? item.priority,
      if (item.statusName != null) item.statusName!,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? TaktColors.surfaceDark : TaktColors.surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(TaktRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            item.title,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3, color: fg),
          ),
          const SizedBox(height: 4),
          Text(meta, style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final a in CheckinAnswer.values) ...[
                if (a != CheckinAnswer.values.first) const SizedBox(width: 6),
                Expanded(
                  child: _AnswerButton(
                    answer: a,
                    selected: choice?.answer == a,
                    dark: dark,
                    onTap: busy ? null : () => onPick(a),
                  ),
                ),
              ],
            ],
          ),
          if (choice?.answer == CheckinAnswer.blocked) ...[
            const SizedBox(height: 8),
            TextField(
              controller: reason,
              enabled: !busy,
              maxLength: checkinReasonMax,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Что мешает? (необязательно)',
                isDense: true,
                counterText: '',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.answer,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  final CheckinAnswer answer;
  final bool selected;
  final bool dark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = answerColor(answer, dark);
    // Выбранный ответ — заливка: выбор читается сразу.
    final onColor = dark ? const Color(0xFF152028) : Colors.white;
    final idle = dark ? TaktColors.foregroundDark : TaktColors.graphite;
    final border = dark ? TaktColors.borderStrongDark : TaktColors.borderStrong;
    return Semantics(
      selected: selected,
      button: true,
      label: answer.label,
      child: Material(
        color: selected ? color : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TaktRadii.md),
          side: BorderSide(color: selected ? color : border, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(TaktRadii.md),
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(_answerIcon(answer), size: 18, color: selected ? onColor : idle),
                const SizedBox(height: 3),
                Text(
                  answer.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? onColor : idle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

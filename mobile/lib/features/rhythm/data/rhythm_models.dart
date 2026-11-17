import 'package:equatable/equatable.dart';

/// Ответ по задаче в чек-ине.
enum CheckinAnswer {
  done('done', 'Сделал'),
  inProgress('in_progress', 'В работе'),
  blocked('blocked', 'Застрял');

  const CheckinAnswer(this.wire, this.label);

  final String wire;
  final String label;

  static CheckinAnswer? fromWire(String? v) {
    for (final a in values) {
      if (a.wire == v) return a;
    }
    return null;
  }
}

const int checkinReasonMax = 280;

class CheckinItem extends Equatable {
  const CheckinItem({
    required this.taskId,
    required this.title,
    required this.priority,
    this.dueDate,
    this.statusName,
    this.answer,
    this.reason,
  });

  final String taskId;
  final String title;
  final String priority;
  final String? dueDate;
  final String? statusName;
  final CheckinAnswer? answer;
  final String? reason;

  factory CheckinItem.fromJson(Map<String, dynamic> json) => CheckinItem(
        taskId: json['task_id'] as String,
        title: json['title'] as String? ?? 'Задача',
        priority: json['priority'] as String? ?? 'medium',
        dueDate: json['due_date'] as String?,
        statusName: (json['status'] as Map<String, dynamic>?)?['name'] as String?,
        answer: CheckinAnswer.fromWire(json['answer'] as String?),
        reason: json['reason'] as String?,
      );

  @override
  List<Object?> get props => [taskId, title, priority, dueDate, statusName, answer, reason];
}

class Checkin extends Equatable {
  const Checkin({
    required this.id,
    required this.status,
    required this.items,
    this.projectId,
    this.projectName,
    this.date,
    this.actionToken,
    this.actionPath,
  });

  final String id;
  final String status; // pending | answered | skipped
  final String? projectId;
  final String? projectName;
  final String? date;
  final List<CheckinItem> items;

  /// Токен только на этот чек-ин и сегодня — для виджета и Live Activity (не JWT).
  final String? actionToken;
  final String? actionPath;

  bool get isPending => status == 'pending';
  int get unanswered => items.where((i) => i.answer == null).length;

  factory Checkin.fromJson(Map<String, dynamic> json) {
    final project = json['project'] as Map<String, dynamic>?;
    return Checkin(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'pending',
      projectId: project?['id'] as String?,
      projectName: project?['name'] as String?,
      date: json['date'] as String?,
      actionToken: json['action_token'] as String?,
      actionPath: json['action_path'] as String?,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => CheckinItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [id, status, projectId, projectName, date, items];
}

class CheckinChoice extends Equatable {
  const CheckinChoice(this.answer, [this.reason]);

  final CheckinAnswer answer;
  final String? reason;

  @override
  List<Object?> get props => [answer, reason];
}

/// Уже данные ответы — стартовый выбор на экране.
Map<String, CheckinChoice> initialChoices(Checkin c) => {
      for (final i in c.items)
        if (i.answer != null) i.taskId: CheckinChoice(i.answer!, i.reason),
    };

/// Тело POST `/answer`: только новые или изменённые ответы; причина ≤ 280.
List<Map<String, dynamic>> buildCheckinAnswers(
  Checkin checkin,
  Map<String, CheckinChoice> choices,
) {
  final out = <Map<String, dynamic>>[];
  for (final item in checkin.items) {
    final c = choices[item.taskId];
    if (c == null) continue;
    var reason = '';
    if (c.answer == CheckinAnswer.blocked) {
      reason = (c.reason ?? '').trim();
      if (reason.length > checkinReasonMax) reason = reason.substring(0, checkinReasonMax);
    }
    final same = item.answer == c.answer &&
        (c.answer != CheckinAnswer.blocked || (item.reason ?? '') == reason);
    if (same) continue;
    out.add({
      'task_id': item.taskId,
      'answer': c.answer.wire,
      if (reason.isNotEmpty) 'reason': reason,
    });
  }
  return out;
}

String tasksWord(int n) {
  final n100 = n % 100;
  final n10 = n % 10;
  if (n100 >= 11 && n100 <= 14) return 'задач';
  if (n10 == 1) return 'задача';
  if (n10 >= 2 && n10 <= 4) return 'задачи';
  return 'задач';
}

/// Текст баннера «Чек-ин на сегодня · N задач» или null, если отвечать не на что.
String? checkinBannerText(List<Checkin> checkins) {
  final left = checkins.where((c) => c.isPending).fold<int>(0, (n, c) => n + c.unanswered);
  if (left == 0) return null;
  return 'Чек-ин на сегодня · $left ${tasksWord(left)}';
}

/// Проект для «Пройти чек-ин сейчас»: только без активного чек-ина; текущий — в приоритете.
String? checkinStartProjectId(
  List<Checkin> checkins,
  List<String> startable, {
  String? currentProjectId,
}) {
  if (startable.isEmpty || checkinBannerText(checkins) != null) return null;
  if (currentProjectId != null && startable.contains(currentProjectId)) return currentProjectId;
  return startable.first;
}

/// Данные для виджета «Чек-ин» / Live Activity: первый неотвеченный чек-ин на сегодня.
Map<String, dynamic>? checkinWidgetPayload(List<Checkin> checkins) {
  final c = checkins.where((x) => x.isPending && x.unanswered > 0).firstOrNull;
  if (c == null || c.actionToken == null) return null;
  return {
    'checkin_id': c.id,
    'project_id': c.projectId,
    'project_name': c.projectName,
    'date': c.date,
    'token': c.actionToken,
    'action_path': c.actionPath ?? '/api/v1/rhythm/push-answer',
    'total': c.items.length,
    'answered': c.items.length - c.unanswered,
    'tasks': [
      for (final i in c.items)
        {
          'id': i.taskId,
          'title': i.title,
          'priority': i.priority,
          'answer': i.answer?.wire,
        },
    ],
  };
}

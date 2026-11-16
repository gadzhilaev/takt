import 'package:equatable/equatable.dart';

/// Сводка проекта (`GET /api/v1/projects/{id}/digest`).
enum DigestPeriod {
  day('day', 'День'),
  week('week', 'Неделя'),
  month('month', 'Месяц');

  const DigestPeriod(this.wire, this.label);
  final String wire;
  final String label;

  static DigestPeriod fromWire(String? v) =>
      values.firstWhere((p) => p.wire == v, orElse: () => DigestPeriod.week);
}

class DigestTask extends Equatable {
  const DigestTask({
    required this.taskId,
    required this.title,
    required this.priority,
    this.assignees = const [],
    this.dueDate,
    this.reason,
    this.blockedBy,
    this.daysStuck,
    this.hoursInStatus,
  });

  final String taskId;
  final String title;
  final String priority;
  final List<String> assignees;
  final String? dueDate;
  final String? reason;
  final String? blockedBy;
  final int? daysStuck;
  final double? hoursInStatus;

  factory DigestTask.fromJson(Map<String, dynamic> j) => DigestTask(
        taskId: j['task_id'] as String,
        title: j['title'] as String? ?? 'Задача',
        priority: j['priority'] as String? ?? 'medium',
        assignees: [for (final a in (j['assignees'] as List? ?? const [])) '$a'],
        dueDate: j['due_date'] as String?,
        reason: j['reason'] as String?,
        blockedBy: j['blocked_by'] as String?,
        daysStuck: (j['days_stuck'] as num?)?.toInt(),
        hoursInStatus: (j['hours_in_status'] as num?)?.toDouble(),
      );

  @override
  List<Object?> get props => [taskId, title, priority, assignees, dueDate, reason, daysStuck];
}

class DigestMissed extends Equatable {
  const DigestMissed({required this.name, required this.missed, required this.total});
  final String name;
  final int missed;
  final int total;

  @override
  List<Object?> get props => [name, missed, total];
}

class Digest extends Equatable {
  const Digest({
    required this.projectId,
    required this.projectName,
    required this.period,
    required this.start,
    required this.end,
    required this.done,
    required this.stuck,
    required this.overdue,
    required this.dueSoon,
    required this.participation,
    required this.stuckTasks,
    required this.overdueTasks,
    required this.dueSoonTasks,
    required this.doneTasks,
    required this.rhythmEnabled,
    required this.rhythmTotal,
    required this.rhythmAnswered,
    required this.missed,
    required this.isAdmin,
    required this.subscribed,
    this.bottleneckName,
    this.bottleneckHours,
    this.bottleneckTasks = const [],
  });

  final String projectId;
  final String projectName;
  final DigestPeriod period;
  final String start;
  final String end;
  final int done;
  final int stuck;
  final int overdue;
  final int dueSoon;
  final int? participation;
  final List<DigestTask> stuckTasks;
  final List<DigestTask> overdueTasks;
  final List<DigestTask> dueSoonTasks;
  final List<DigestTask> doneTasks;
  final String? bottleneckName;
  final double? bottleneckHours;
  final List<DigestTask> bottleneckTasks;
  final bool rhythmEnabled;
  final int rhythmTotal;
  final int rhythmAnswered;
  final List<DigestMissed> missed;
  final bool isAdmin;
  final bool subscribed;

  factory Digest.fromJson(Map<String, dynamic> j) {
    List<DigestTask> tasks(Object? v) => [
          for (final t in (v as List? ?? const []))
            DigestTask.fromJson(Map<String, dynamic>.from(t as Map)),
        ];
    final s = Map<String, dynamic>.from(j['summary'] as Map);
    final p = Map<String, dynamic>.from(j['period'] as Map);
    final r = Map<String, dynamic>.from(j['rhythm'] as Map? ?? const {});
    final b = j['bottleneck'] as Map?;
    final viewer = Map<String, dynamic>.from(j['viewer'] as Map? ?? const {});
    final project = Map<String, dynamic>.from(j['project'] as Map);
    return Digest(
      projectId: project['id'] as String,
      projectName: project['name'] as String? ?? '',
      period: DigestPeriod.fromWire(p['kind'] as String?),
      start: p['start'] as String,
      end: p['end'] as String,
      done: (s['done'] as num).toInt(),
      stuck: (s['stuck'] as num).toInt(),
      overdue: (s['overdue'] as num).toInt(),
      dueSoon: (s['due_soon'] as num? ?? 0).toInt(),
      participation: (s['participation'] as num?)?.toInt(),
      stuckTasks: tasks(j['stuck']),
      overdueTasks: tasks(j['overdue']),
      dueSoonTasks: tasks(j['due_soon']),
      doneTasks: tasks(j['done']),
      bottleneckName: b?['name'] as String?,
      bottleneckHours: (b?['avg_hours'] as num?)?.toDouble(),
      bottleneckTasks: tasks(b?['tasks']),
      rhythmEnabled: r['enabled'] as bool? ?? false,
      rhythmTotal: (r['total'] as num? ?? 0).toInt(),
      rhythmAnswered: (r['answered'] as num? ?? 0).toInt(),
      missed: [
        for (final m in (r['members_without_answer'] as List? ?? const []))
          DigestMissed(
            name: (m as Map)['name'] as String? ?? '',
            missed: (m['missed'] as num).toInt(),
            total: (m['total'] as num).toInt(),
          ),
      ],
      isAdmin: viewer['is_admin'] as bool? ?? false,
      subscribed: viewer['subscribed'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [projectId, period, start, end, done, stuck, overdue, participation];
}

/// 30 → «1 д. 6 ч.», 5.5 → «5 ч.», 0.4 → «< 1 ч.».
String formatDigestHours(double hours) {
  if (hours < 1) return '< 1 ч.';
  final d = hours ~/ 24;
  final h = (hours - d * 24).round();
  if (d == 0) return '$h ч.';
  return h == 0 ? '$d д.' : '$d д. $h ч.';
}

String digestDaysLabel(int n) {
  if (n <= 0) return 'меньше дня';
  final n10 = n % 10;
  final n100 = n % 100;
  if (n100 >= 11 && n100 <= 14) return '$n дней';
  if (n10 == 1) return '$n день';
  if (n10 >= 2 && n10 <= 4) return '$n дня';
  return '$n дней';
}

/// «12.11 — 18.11».
String digestPeriodLabel(String start, String end) {
  String fmt(String iso) {
    final parts = iso.split('-');
    return parts.length == 3 ? '${parts[2]}.${parts[1]}' : iso;
  }

  return start == end ? fmt(end) : '${fmt(start)} — ${fmt(end)}';
}

String digestParticipation(int? p) => p == null ? '—' : '$p%';

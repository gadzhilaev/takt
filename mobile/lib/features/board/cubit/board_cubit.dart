import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../../../shared/models/models.dart';
import '../../projects/data/projects_repository.dart';
import '../../widget_sync/widget_sync.dart';
import '../data/board_repository.dart';

class BoardState extends Equatable {
  const BoardState({
    this.projects = const [],
    this.project,
    this.columns = const [],
    this.tasks = const [],
    this.columnIndex = 0,
    this.loading = false,
    this.offline = false,
    this.error,
  });

  final List<Project> projects;
  final Project? project;
  final List<StatusColumn> columns;
  final List<TaskItem> tasks;
  final int columnIndex;
  final bool loading;
  final bool offline;
  final String? error;

  StatusColumn? get currentColumn =>
      columns.isEmpty ? null : columns[columnIndex.clamp(0, columns.length - 1)];

  List<TaskItem> get currentTasks {
    final col = currentColumn;
    if (col == null) return const [];
    return tasks.where((t) => t.statusId == col.id).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  BoardState copyWith({
    List<Project>? projects,
    Project? project,
    List<StatusColumn>? columns,
    List<TaskItem>? tasks,
    int? columnIndex,
    bool? loading,
    bool? offline,
    String? error,
    bool clearError = false,
  }) =>
      BoardState(
        projects: projects ?? this.projects,
        project: project ?? this.project,
        columns: columns ?? this.columns,
        tasks: tasks ?? this.tasks,
        columnIndex: columnIndex ?? this.columnIndex,
        loading: loading ?? this.loading,
        offline: offline ?? this.offline,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props =>
      [projects, project, columns, tasks, columnIndex, loading, offline, error];
}

class BoardCubit extends Cubit<BoardState> {
  BoardCubit({
    required BoardRepository board,
    required ProjectsRepository projects,
    required ApiClient api,
    required WidgetSync widgetSync,
  })  : _board = board,
        _projects = projects,
        _api = api,
        _widgetSync = widgetSync,
        super(const BoardState());

  final BoardRepository _board;
  final ProjectsRepository _projects;
  final ApiClient _api;
  final WidgetSync _widgetSync;

  static const _lastProjectKey = 'takt_last_project_id';

  Future<void> bootstrap() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final projects = await _projects.listProjects();
      final prefs = await SharedPreferences.getInstance();
      final lastId = prefs.getString(_lastProjectKey);
      Project? selected;
      if (projects.isNotEmpty) {
        for (final p in projects) {
          if (p.id == lastId) {
            selected = p;
            break;
          }
        }
        selected ??= projects.cast<Project?>().firstWhere(
              (p) => p!.name == 'Колледж ДГУ',
              orElse: () => null,
            );
        selected ??= projects.first;
      }
      if (selected == null) {
        emit(state.copyWith(projects: projects, loading: false, project: null));
        return;
      }
      await openProject(selected.id, projects: projects);
    } catch (e) {
      emit(state.copyWith(
        loading: false,
        offline: true,
        error: _api.messageFromError(e),
      ));
    }
  }

  Future<void> openProject(String projectId, {List<Project>? projects}) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final list = projects ?? state.projects;
      final project = list.firstWhere(
        (p) => p.id == projectId,
        orElse: () => list.isNotEmpty ? list.first : (throw StateError('no project')),
      );
      final board = await _board.loadBoard(projectId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastProjectKey, projectId);
      emit(state.copyWith(
        projects: list.isEmpty ? [project] : list,
        project: project,
        columns: board.columns,
        tasks: board.tasks,
        columnIndex: 0,
        loading: false,
        offline: false,
      ));
      await _widgetSync.publishBoard(
        project: project,
        columns: board.columns,
        tasks: board.tasks,
      );
    } catch (e) {
      emit(state.copyWith(loading: false, offline: true, error: _api.messageFromError(e)));
    }
  }

  void selectColumn(int index) {
    if (state.columns.isEmpty) return;
    emit(state.copyWith(columnIndex: index.clamp(0, state.columns.length - 1)));
  }

  Future<void> createTask({
    required String title,
    String? description,
    String priority = 'medium',
    List<String> assigneeIds = const [],
  }) async {
    final project = state.project;
    final col = state.currentColumn;
    if (project == null || col == null) return;
    if (state.offline) {
      emit(state.copyWith(error: 'Нет сети — создание задачиблокировано'));
      return;
    }
    try {
      final task = await _board.createTask(
        projectId: project.id,
        statusId: col.id,
        title: title,
        description: description,
        priority: priority,
        assigneeIds: assigneeIds,
      );
      final next = [task, ...state.tasks.where((t) => t.id != task.id)];
      emit(state.copyWith(tasks: next, clearError: true));
      await _widgetSync.publishBoard(
        project: project,
        columns: state.columns,
        tasks: next,
      );
    } catch (e) {
      emit(state.copyWith(error: _api.messageFromError(e)));
    }
  }

  Future<void> moveToColumn(TaskItem task, String statusId) async {
    if (state.offline) {
      emit(state.copyWith(error: 'Нет сети — перемещение заблокировано'));
      return;
    }
    final peers = state.tasks.where((t) => t.statusId == statusId && t.id != task.id);
    final minPos = peers.isEmpty
        ? 0.0
        : peers.map((t) => t.position).reduce((a, b) => a < b ? a : b);
    final position = peers.isEmpty ? 0.0 : minPos - 1024;
    try {
      final updated = await _board.moveTask(
        taskId: task.id,
        statusId: statusId,
        position: position,
      );
      final next = state.tasks.map((t) => t.id == updated.id ? updated : t).toList();
      emit(state.copyWith(tasks: next, clearError: true));
      if (state.project != null) {
        await _widgetSync.publishBoard(
          project: state.project!,
          columns: state.columns,
          tasks: next,
        );
      }
    } catch (e) {
      emit(state.copyWith(error: _api.messageFromError(e)));
    }
  }

  Future<void> updateTask(TaskItem updated) async {
    if (state.offline) {
      emit(state.copyWith(error: 'Нет сети — изменение заблокировано'));
      return;
    }
    try {
      final saved = await _board.updateTask(
        taskId: updated.id,
        title: updated.title,
        description: updated.description,
        priority: updated.priority,
        statusId: updated.statusId,
        assigneeIds: updated.assignees.map((a) => a.id).toList(),
      );
      final next = state.tasks.map((t) => t.id == saved.id ? saved : t).toList();
      emit(state.copyWith(tasks: next, clearError: true));
    } catch (e) {
      emit(state.copyWith(error: _api.messageFromError(e)));
    }
  }

  Future<void> createProject(String name) async {
    try {
      final p = await _projects.createProject(name: name);
      final list = [...state.projects, p];
      emit(state.copyWith(projects: list));
      await openProject(p.id, projects: list);
    } catch (e) {
      emit(state.copyWith(error: _api.messageFromError(e)));
    }
  }
}

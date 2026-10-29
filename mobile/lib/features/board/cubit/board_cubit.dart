import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../../../shared/models/models.dart';
import '../../../shared/project_visibility.dart';
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
    bool clearProject = false,
  }) =>
      BoardState(
        projects: projects ?? this.projects,
        project: clearProject ? null : (project ?? this.project),
        columns: clearProject ? const [] : (columns ?? this.columns),
        tasks: clearProject ? const [] : (tasks ?? this.tasks),
        columnIndex: clearProject ? 0 : (columnIndex ?? this.columnIndex),
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
    required this.board,
    required this.projects,
    required this.api,
    required this.widgetSync,
  }) : super(const BoardState());

  final BoardRepository board;
  final ProjectsRepository projects;
  final ApiClient api;
  final WidgetSync widgetSync;

  /// Set from AuthCubit so widgets only show tasks assigned to this user.
  String? currentUserId;

  static const _lastProjectKey = 'takt_last_project_id';

  void setCurrentUserId(String? id) {
    currentUserId = id;
    if (id != null && state.project != null) {
      unawaited(_publishWidget());
    }
  }

  Future<void> _publishWidget() async {
    final project = state.project;
    final userId = currentUserId;
    if (project == null || userId == null || userId.isEmpty) return;
    await widgetSync.publishBoard(
      project: project,
      columns: state.columns,
      tasks: state.tasks,
      currentUserId: userId,
      allProjects: state.projects,
    );
  }

  Future<void> bootstrap({String? preferProjectId}) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final projects = await this.projects.listProjects();
      final visible = projects.where((p) => !taktIsTestProject(p)).toList();
      // Deep link / explicit project — open immediately; otherwise show hub.
      String? openId = preferProjectId;
      if (openId != null && openId.isNotEmpty) {
        final match = visible.where((p) => p.id == openId).toList();
        if (match.isEmpty) openId = null;
      }
      if (openId != null) {
        await openProject(openId, projects: projects);
        return;
      }
      emit(state.copyWith(
        projects: projects,
        loading: false,
        clearProject: true,
        offline: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        loading: false,
        offline: true,
        error: api.messageFromError(e),
      ));
    }
  }

  Future<void> refreshProjects() async {
    try {
      final projects = await this.projects.listProjects();
      final currentId = state.project?.id;
      Project? project = state.project;
      if (currentId != null) {
        final matches = projects.where((p) => p.id == currentId);
        project = matches.isEmpty ? null : matches.first;
      }
      if (project == null && currentId != null) {
        emit(state.copyWith(projects: projects, clearProject: true));
      } else {
        emit(state.copyWith(projects: projects, project: project));
      }
    } catch (e) {
      emit(state.copyWith(error: api.messageFromError(e)));
    }
  }

  void clearProject() {
    emit(state.copyWith(clearProject: true, clearError: true));
  }

  Future<void> openProject(String projectId, {List<Project>? projects}) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final list = projects ?? state.projects;
      final project = list.firstWhere(
        (p) => p.id == projectId,
        orElse: () => list.isNotEmpty ? list.first : (throw StateError('no project')),
      );
      final loaded = await board.loadBoard(projectId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastProjectKey, projectId);
      emit(state.copyWith(
        projects: list.isEmpty ? [project] : list,
        project: project,
        columns: loaded.columns,
        tasks: loaded.tasks,
        columnIndex: 0,
        loading: false,
        offline: false,
      ));
      await _publishWidget();
    } catch (e) {
      emit(state.copyWith(loading: false, offline: true, error: api.messageFromError(e)));
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
    String? statusId,
  }) async {
    final project = state.project;
    final col = state.currentColumn;
    final targetStatusId = statusId ?? col?.id;
    if (project == null || targetStatusId == null) return;
    if (state.offline) {
      emit(state.copyWith(error: 'Нет сети: создание задачи блокировано'));
      return;
    }
    try {
      final task = await board.createTask(
        projectId: project.id,
        statusId: targetStatusId,
        title: title,
        description: description,
        priority: priority,
        assigneeIds: assigneeIds,
      );
      final next = [task, ...state.tasks.where((t) => t.id != task.id)];
      emit(state.copyWith(tasks: next, clearError: true));
      await _publishWidget();
    } catch (e) {
      emit(state.copyWith(error: api.messageFromError(e)));
    }
  }

  Future<void> moveToColumn(TaskItem task, String statusId) async {
    if (state.offline) {
      emit(state.copyWith(error: 'Нет сети: перемещение заблокировано'));
      return;
    }
    final peers = state.tasks.where((t) => t.statusId == statusId && t.id != task.id);
    final minPos = peers.isEmpty
        ? 0.0
        : peers.map((t) => t.position).reduce((a, b) => a < b ? a : b);
    final position = peers.isEmpty ? 0.0 : minPos - 1024;
    try {
      final updated = await board.moveTask(
        taskId: task.id,
        statusId: statusId,
        position: position,
      );
      final next = state.tasks.map((t) => t.id == updated.id ? updated : t).toList();
      emit(state.copyWith(tasks: next, clearError: true));
      await _publishWidget();
    } catch (e) {
      emit(state.copyWith(error: api.messageFromError(e)));
    }
  }

  Future<void> updateTask(TaskItem updated) async {
    if (state.offline) {
      emit(state.copyWith(error: 'Нет сети: изменение заблокировано'));
      return;
    }
    try {
      final saved = await board.updateTask(
        taskId: updated.id,
        title: updated.title,
        description: updated.description,
        priority: updated.priority,
        statusId: updated.statusId,
        assigneeIds: updated.assignees.map((a) => a.id).toList(),
      );
      final next = state.tasks.map((t) => t.id == saved.id ? saved : t).toList();
      emit(state.copyWith(tasks: next, clearError: true));
      await _publishWidget();
    } catch (e) {
      emit(state.copyWith(error: api.messageFromError(e)));
    }
  }

  Future<void> createProject(String name) async {
    try {
      final p = await projects.createProject(name: name);
      final list = [...state.projects, p];
      emit(state.copyWith(projects: list));
      await openProject(p.id, projects: list);
    } catch (e) {
      emit(state.copyWith(error: api.messageFromError(e)));
    }
  }

  Future<void> deleteTask(String taskId) async {
    if (state.offline) {
      emit(state.copyWith(error: 'Нет сети: удаление заблокировано'));
      return;
    }
    try {
      await board.deleteTask(taskId);
      final next = state.tasks.where((t) => t.id != taskId).toList();
      emit(state.copyWith(tasks: next, clearError: true));
      await _publishWidget();
    } catch (e) {
      emit(state.copyWith(error: api.messageFromError(e)));
    }
  }
}

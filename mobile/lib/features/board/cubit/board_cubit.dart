import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../../../shared/models/models.dart';
import '../../../shared/project_visibility.dart';
import '../../projects/data/projects_repository.dart';
import '../../widget_sync/widget_sync.dart';
import '../data/board_local_cache.dart';
import '../data/board_repository.dart';

class BoardState extends Equatable {
  const BoardState({
    this.projects = const [],
    this.project,
    this.columns = const [],
    this.tasks = const [],
    this.columnIndex = 0,
    this.loading = false,
    this.refreshing = false,
    this.offline = false,
    this.error,
  });

  final List<Project> projects;
  final Project? project;
  final List<StatusColumn> columns;
  final List<TaskItem> tasks;
  final int columnIndex;
  /// Full-screen loader — only when there is nothing local to show.
  final bool loading;
  /// Background / pull refresh without blanking the UI.
  final bool refreshing;
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
    bool? refreshing,
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
        refreshing: refreshing ?? this.refreshing,
        offline: offline ?? this.offline,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [
        projects,
        project,
        columns,
        tasks,
        columnIndex,
        loading,
        refreshing,
        offline,
        error,
      ];
}

class BoardCubit extends Cubit<BoardState> {
  BoardCubit({
    required this.board,
    required this.projects,
    required this.api,
    required this.widgetSync,
    BoardLocalCache? cache,
  })  : cache = cache ?? BoardLocalCache(),
        super(const BoardState());

  final BoardRepository board;
  final ProjectsRepository projects;
  final ApiClient api;
  final WidgetSync widgetSync;
  final BoardLocalCache cache;

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

  Future<void> _persistBoard() async {
    final project = state.project;
    if (project == null || state.columns.isEmpty) return;
    await cache.saveBoard(
      project: project,
      columns: state.columns,
      tasks: state.tasks,
    );
  }

  bool _sameProjects(List<Project> a, List<Project> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _sameBoardData({
    required List<StatusColumn> columns,
    required List<TaskItem> tasks,
    Project? project,
  }) {
    if (project != null && state.project != project) return false;
    if (columns.length != state.columns.length || tasks.length != state.tasks.length) {
      return false;
    }
    for (var i = 0; i < columns.length; i++) {
      if (columns[i] != state.columns[i]) return false;
    }
    for (var i = 0; i < tasks.length; i++) {
      if (tasks[i] != state.tasks[i]) return false;
    }
    return true;
  }

  /// Disk → memory without network. Splash / cold start show data immediately.
  Future<void> hydrateFromCache() async {
    if (state.projects.isNotEmpty) return;
    final list = await cache.loadProjects();
    if (list.isEmpty) return;
    final visible = list.where((p) => !taktIsTestProject(p)).toList();
    emit(state.copyWith(
      projects: visible.isEmpty ? list : visible,
      loading: false,
      clearError: true,
    ));
  }

  /// First open / cold start. Shows disk/memory cache immediately, then syncs.
  /// [forceLoading] blanks the UI only when there is nothing local.
  Future<void> bootstrap({String? preferProjectId, bool forceLoading = false}) async {
    var list = state.projects;
    if (list.isEmpty) {
      list = await cache.loadProjects();
      if (list.isNotEmpty) {
        final visible = list.where((p) => !taktIsTestProject(p)).toList();
        emit(state.copyWith(
          projects: visible.isEmpty ? list : visible,
          loading: false,
          clearError: true,
        ));
        list = state.projects;
      }
    }

    final hasLocal = list.isNotEmpty;
    // Не бланкуем UI: loading только если совсем пусто.
    if (!hasLocal) {
      emit(state.copyWith(loading: true, clearError: true));
    }

    try {
      final projects = await this.projects.listProjects();
      await cache.saveProjects(projects);
      final visible = projects.where((p) => !taktIsTestProject(p)).toList();
      // Сервер — источник истины: пустой список затирает локальный кэш на экране.
      if (visible.isEmpty) {
        await cache.clearAll();
        emit(state.copyWith(
          projects: const [],
          loading: false,
          refreshing: false,
          clearProject: true,
          offline: false,
          clearError: true,
        ));
        return;
      }
      String? openId = preferProjectId;
      if (openId != null && openId.isNotEmpty) {
        final match = visible.where((p) => p.id == openId).toList();
        if (match.isEmpty) openId = null;
      }
      if (openId != null) {
        await openProject(openId, projects: visible, forceLoading: forceLoading);
        return;
      }
      if (_sameProjects(visible, state.projects) && state.project == null) {
        emit(state.copyWith(loading: false, refreshing: false, offline: false, clearError: true));
      } else {
        emit(state.copyWith(
          projects: visible,
          loading: false,
          refreshing: false,
          clearProject: true,
          offline: false,
          clearError: true,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        loading: false,
        refreshing: false,
        offline: true,
        error: hasLocal ? null : api.messageFromError(e),
      ));
    }
  }

  /// Silent by default — keeps hub content on screen (no spinner except pull-to-refresh UI).
  Future<void> refreshProjects({bool forceLoading = false}) async {
    if (forceLoading && state.projects.isEmpty) {
      emit(state.copyWith(loading: true, clearError: true));
    }
    try {
      final projects = await this.projects.listProjects();
      await cache.saveProjects(projects);
      final visible = projects.where((p) => !taktIsTestProject(p)).toList();
      final currentId = state.project?.id;
      Project? project = state.project;
      if (currentId != null) {
        final matches = visible.where((p) => p.id == currentId);
        project = matches.isEmpty ? null : matches.first;
      }
      if (project == null && currentId != null) {
        emit(state.copyWith(
          projects: visible,
          clearProject: true,
          loading: false,
          refreshing: false,
          offline: false,
          clearError: true,
        ));
      } else if (_sameProjects(visible, state.projects) &&
          (project == null || project == state.project)) {
        emit(state.copyWith(loading: false, refreshing: false, offline: false, clearError: true));
      } else {
        emit(state.copyWith(
          projects: visible,
          project: project,
          loading: false,
          refreshing: false,
          offline: false,
          clearError: true,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        loading: false,
        refreshing: false,
        offline: true,
        error: state.projects.isEmpty ? api.messageFromError(e) : null,
      ));
    }
  }

  void clearProject() {
    emit(state.copyWith(clearProject: true, clearError: true));
  }

  /// Сброс памяти + диска (logout или когда на сервере больше нет проектов).
  Future<void> clearLocal() async {
    await cache.clearAll();
    emit(const BoardState());
  }

  /// Opens a project: hydrate from memory/disk first, then fetch in background.
  /// Returns as soon as something is on screen (cache/memory); network may still run.
  Future<void> openProject(
    String projectId, {
    List<Project>? projects,
    bool forceLoading = false,
  }) async {
    final list = projects ?? state.projects;
    Project? project;
    for (final p in list) {
      if (p.id == projectId) {
        project = p;
        break;
      }
    }

    final memoryHit = state.project?.id == projectId && state.columns.isNotEmpty;
    var hasLocal = memoryHit;

    if (memoryHit && !forceLoading) {
      // Тихий фон: без флагов loading/refreshing — UI уже с кэша.
      unawaited(_fetchBoard(projectId: projectId, list: list, project: project));
      return;
    }

    if (!memoryHit) {
      final cached = await cache.loadBoard(projectId);
      if (cached != null) {
        final localProject = project ?? cached.project;
        project = localProject;
        hasLocal = true;
        emit(state.copyWith(
          projects: list.isEmpty ? [cached.project] : list,
          project: localProject,
          columns: cached.columns,
          tasks: cached.tasks,
          columnIndex: 0,
          loading: false,
          refreshing: false,
          clearError: true,
        ));
        if (!forceLoading) {
          unawaited(_fetchBoard(projectId: projectId, list: list, project: localProject));
          return;
        }
      }
    }

    if (!hasLocal) {
      emit(state.copyWith(loading: true, clearError: true));
    }

    await _fetchBoard(projectId: projectId, list: list, project: project);
  }

  Future<void> _fetchBoard({
    required String projectId,
    required List<Project> list,
    Project? project,
  }) async {
    final hadLocal = state.project?.id == projectId && state.columns.isNotEmpty;
    try {
      project ??= list.isNotEmpty
          ? list.firstWhere(
              (p) => p.id == projectId,
              orElse: () => list.first,
            )
          : null;
      if (project == null) {
        throw StateError('no project');
      }
      final loaded = await board.loadBoard(projectId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastProjectKey, projectId);
      final keepColumn = state.project?.id == projectId ? state.columnIndex : 0;
      final nextProjects = list.isEmpty ? [project] : list;
      if (_sameBoardData(columns: loaded.columns, tasks: loaded.tasks, project: project) &&
          _sameProjects(nextProjects, state.projects)) {
        emit(state.copyWith(loading: false, refreshing: false, offline: false, clearError: true));
      } else {
        emit(state.copyWith(
          projects: nextProjects,
          project: project,
          columns: loaded.columns,
          tasks: loaded.tasks,
          columnIndex: keepColumn.clamp(0, loaded.columns.isEmpty ? 0 : loaded.columns.length - 1),
          loading: false,
          refreshing: false,
          offline: false,
          clearError: true,
        ));
      }
      await cache.saveBoard(
        project: project,
        columns: loaded.columns,
        tasks: loaded.tasks,
      );
      await _publishWidget();
    } catch (e) {
      emit(state.copyWith(
        loading: false,
        refreshing: false,
        offline: true,
        error: hadLocal ? null : api.messageFromError(e),
      ));
    }
  }

  /// Pull-to-refresh: визуальный индикатор у RefreshIndicator, контент не бланкуем.
  Future<void> refreshBoard({bool forceLoading = false}) async {
    final project = state.project;
    if (project == null) {
      await refreshProjects(forceLoading: forceLoading);
      return;
    }
    await openProject(project.id, forceLoading: true);
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
      await _persistBoard();
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
      await _persistBoard();
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
      await _persistBoard();
      await _publishWidget();
    } catch (e) {
      emit(state.copyWith(error: api.messageFromError(e)));
    }
  }

  Future<void> createProject(String name) async {
    try {
      final p = await projects.createProject(name: name);
      final list = [...state.projects, p];
      await cache.saveProjects(list);
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
      await _persistBoard();
      await _publishWidget();
    } catch (e) {
      emit(state.copyWith(error: api.messageFromError(e)));
    }
  }
}

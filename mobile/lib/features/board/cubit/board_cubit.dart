import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../../../core/avatar_cache.dart';
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

  /// Last successful /projects network sync (splash / pull-to-refresh).
  DateTime? _projectsSyncedAt;

  /// Cancels stale background board fetches when switching projects quickly.
  int _boardFetchGen = 0;

  static const _lastProjectKey = 'takt_last_project_id';
  static const _projectsFreshFor = Duration(seconds: 90);

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

  Future<void> _prefetchAvatars({
    List<Project>? projects,
    List<TaskItem>? tasks,
  }) async {
    final proj = projects ?? state.projects;
    final taskList = tasks ?? state.tasks;
    final urls = <String?>[
      ...proj.expand((p) => p.members.map((m) => m.avatarUrl)),
      ...taskList.expand((t) => t.assignees.map((a) => a.avatarUrl)),
      ...taskList.map((t) => t.authorAvatarUrl),
    ];
    await AvatarCache.instance.prefetch(urls);
  }

  /// Disk → memory without network. Splash / cold start show data immediately.
  Future<void> hydrateFromCache() async {
    await AvatarCache.instance.warm();
    if (state.projects.isNotEmpty) {
      await _prefetchAvatars();
      return;
    }
    final list = await cache.loadProjects();
    if (list.isEmpty) return;
    final visible = list.where((p) => !taktIsTestProject(p)).toList();
    final projects = visible.isEmpty ? list : visible;
    emit(state.copyWith(
      projects: projects,
      loading: false,
      clearError: true,
    ));
    // Прогреть аватары с диска/сети до ухода со splash.
    final taskUrls = <String?>[];
    for (final p in projects.take(8)) {
      final board = await cache.loadBoard(p.id);
      if (board == null) continue;
      for (final t in board.tasks) {
        for (final a in t.assignees) {
          taskUrls.add(a.avatarUrl);
        }
      }
    }
    await _prefetchAvatars(projects: projects, tasks: const []);
    await AvatarCache.instance.prefetch(taskUrls);
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
      _projectsSyncedAt = DateTime.now();
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
      // Кэш на экране — не помечаем «офлайн» из-за таймаута одного запроса.
      emit(state.copyWith(
        loading: false,
        refreshing: false,
        offline: false,
        error: hasLocal ? null : api.messageFromError(e),
      ));
    }
  }

  /// Silent by default — keeps hub content on screen (no spinner except pull-to-refresh UI).
  Future<void> refreshProjects({bool forceLoading = false}) async {
    final synced = _projectsSyncedAt;
    if (!forceLoading &&
        state.projects.isNotEmpty &&
        synced != null &&
        DateTime.now().difference(synced) < _projectsFreshFor) {
      return;
    }
    if (forceLoading && state.projects.isEmpty) {
      emit(state.copyWith(loading: true, clearError: true));
    }
    try {
      final projects = await this.projects.listProjects();
      await cache.saveProjects(projects);
      _projectsSyncedAt = DateTime.now();
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
        offline: false,
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
    final gen = ++_boardFetchGen;
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
      if (gen != _boardFetchGen || isClosed) return;
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
      unawaited(_prefetchAvatars(projects: nextProjects, tasks: loaded.tasks));
      await _publishWidget();
    } catch (e) {
      if (gen != _boardFetchGen || isClosed) return;
      // Устаревший/фоновый таймаут не блокирует доску с кэшем.
      if (state.project?.id != null && state.project?.id != projectId) return;
      emit(state.copyWith(
        loading: false,
        refreshing: false,
        offline: false,
        error: hadLocal ? null : api.messageFromError(e),
      ));
    }
  }

  /// Pull-to-refresh / realtime: [forceLoading] true — как жесткий refresh;
  /// false — тихий sync (кэш на экране, сеть в фоне).
  Future<void> refreshBoard({bool forceLoading = false}) async {
    final project = state.project;
    if (project == null) {
      await refreshProjects(forceLoading: forceLoading);
      return;
    }
    await openProject(project.id, forceLoading: forceLoading);
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
    List<({String path, String filename})> files = const [],
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
      var task = await board.createTask(
        projectId: project.id,
        statusId: targetStatusId,
        title: title,
        description: description,
        priority: priority,
        assigneeIds: assigneeIds,
      );
      for (final f in files) {
        final uploaded = await board.uploadAttachment(
          taskId: task.id,
          path: f.path,
          filename: f.filename,
        );
        task = uploaded.task;
      }
      final next = [task, ...state.tasks.where((t) => t.id != task.id)];
      emit(state.copyWith(tasks: next, clearError: true));
      await _persistBoard();
      await _publishWidget();
    } catch (e) {
      emit(state.copyWith(error: api.messageFromError(e)));
    }
  }

  void replaceTask(TaskItem task) {
    final next = state.tasks.map((t) => t.id == task.id ? task : t).toList();
    emit(state.copyWith(tasks: next, clearError: true));
    unawaited(_persistBoard());
  }

  Future<void> moveToColumn(TaskItem task, String statusId) async {
    if (state.offline) {
      emit(state.copyWith(error: 'Нет сети: перемещение заблокировано'));
      return;
    }
    if (task.statusId == statusId) return;
    final peers = state.tasks.where((t) => t.statusId == statusId && t.id != task.id);
    final minPos = peers.isEmpty
        ? 0.0
        : peers.map((t) => t.position).reduce((a, b) => a < b ? a : b);
    final position = peers.isEmpty ? 0.0 : minPos - 1024;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    StatusColumn? target;
    for (final c in state.columns) {
      if (c.id == statusId) {
        target = c;
        break;
      }
    }
    final optimistic = task.copyWith(
      statusId: statusId,
      position: position,
      statusEnteredAt: nowIso,
      closedAt: target?.isDone == true ? nowIso : null,
    );
    final before = state.tasks;
    emit(state.copyWith(
      tasks: before.map((t) => t.id == task.id ? optimistic : t).toList(),
      clearError: true,
    ));
    await _persistBoard();
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
      emit(state.copyWith(tasks: before, error: api.messageFromError(e)));
      await _persistBoard();
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

  Future<StatusColumn?> createColumn({
    required String name,
    required String color,
  }) async {
    final project = state.project;
    if (project == null) return null;
    if (state.offline) {
      emit(state.copyWith(error: 'Нет сети: создание столбца заблокировано'));
      return null;
    }
    try {
      final col = await board.createColumn(
        projectId: project.id,
        name: name,
        color: color,
      );
      final next = [...state.columns, col]..sort((a, b) => a.position.compareTo(b.position));
      final idx = next.indexWhere((c) => c.id == col.id);
      emit(state.copyWith(
        columns: next,
        columnIndex: idx >= 0 ? idx : state.columnIndex,
        clearError: true,
      ));
      await _persistBoard();
      return col;
    } catch (e) {
      emit(state.copyWith(error: api.messageFromError(e)));
      return null;
    }
  }

  Future<void> updateColumnColor({
    required String statusId,
    required String color,
  }) async {
    if (state.offline) {
      emit(state.copyWith(error: 'Нет сети: изменение заблокировано'));
      return;
    }
    try {
      final col = await board.updateColumnColor(statusId: statusId, color: color);
      final next = state.columns.map((c) => c.id == col.id ? col : c).toList();
      emit(state.copyWith(columns: next, clearError: true));
      await _persistBoard();
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

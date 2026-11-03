import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/kanban_colors.dart';
import '../../../core/theme.dart';
import '../../../features/board/cubit/board_cubit.dart';
import '../../../features/board/data/board_repository.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/kanban_column.dart';
import '../../../shared/widgets/kanban_page_physics.dart';
import '../../../shared/widgets/takt_app_bar.dart';

/// «Мои задачи»: Kanban текущего проекта или раскрываемые проекты (как на главной).
class MyTasksPage extends StatefulWidget {
  const MyTasksPage({super.key});

  @override
  State<MyTasksPage> createState() => _MyTasksPageState();
}

class _MyTasksPageState extends State<MyTasksPage> {
  PageController? _pageController;
  int _pageIndex = 0;
  bool _bootstrapped = false;
  bool _dragging = false;

  /// All-projects mode (no active board).
  final List<_ProjectKanbanSection> _sections = [];
  final Set<String> _expanded = {};
  final Set<String> _loadingExpand = {};
  bool _allLoaded = false;
  Object? _allError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureBoard();
    });
  }

  Future<void> _ensureBoard() async {
    final cubit = context.read<BoardCubit>();
    if (cubit.state.project == null) {
      await _loadAllProjects();
      return;
    }
    if (!mounted) return;
    _bootstrapped = true;
    _syncPageController(cubit.state.columnIndex, cubit.state.columns.length);
    setState(() {});
  }

  Future<_ProjectKanbanSection> _sectionForProject({
    required Project project,
    required String userId,
    required BoardCubit cubit,
    required BoardRepository boardRepo,
    Map<String, List<TaskItem>>? mineByProject,
  }) async {
    var columns = <StatusColumn>[];
    var mine = mineByProject?[project.id] ?? <TaskItem>[];

    final cached = await cubit.cache.loadBoard(project.id);
    if (cached != null && cached.columns.isNotEmpty) {
      columns = cached.columns;
      if (mineByProject == null) {
        mine = cached.tasks
            .where((t) => t.assignees.any((a) => a.id == userId))
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position));
      }
    }

    if (columns.isEmpty) {
      try {
        final loaded = await boardRepo.loadBoard(project.id);
        columns = loaded.columns;
        if (mineByProject == null) {
          mine = loaded.tasks
              .where((t) => t.assignees.any((a) => a.id == userId))
              .toList()
            ..sort((a, b) => a.position.compareTo(b.position));
        }
      } catch (_) {
        /* keep empty */
      }
    }

    mine = [...mine]..sort((a, b) => a.position.compareTo(b.position));
    return _ProjectKanbanSection(
      projectId: project.id,
      projectName: project.name,
      columns: columns,
      tasks: mine,
    );
  }

  Future<void> _loadAllProjects({bool fromUser = false}) async {
    final cubit = context.read<BoardCubit>();
    final boardRepo = context.read<BoardRepository>();
    final userId = cubit.currentUserId;
    if (userId == null || userId.isEmpty) {
      if (mounted) {
        setState(() {
          _sections.clear();
          _allLoaded = true;
          _allError = null;
        });
      }
      return;
    }

    if (cubit.state.projects.isEmpty) {
      await cubit.refreshProjects();
    }
    if (!mounted) return;

    // Instant: all projects from cache (even without my tasks).
    final fromCache = <_ProjectKanbanSection>[];
    for (final p in cubit.state.projects) {
      final board = await cubit.cache.loadBoard(p.id);
      final mine = board == null
          ? <TaskItem>[]
          : (board.tasks.where((t) => t.assignees.any((a) => a.id == userId)).toList()
            ..sort((a, b) => a.position.compareTo(b.position)));
      fromCache.add(
        _ProjectKanbanSection(
          projectId: p.id,
          projectName: p.name,
          columns: board?.columns ?? const [],
          tasks: mine,
        ),
      );
    }
    if (mounted && fromCache.isNotEmpty) {
      setState(() {
        _sections
          ..clear()
          ..addAll(fromCache);
        _allError = null;
        if (_expanded.isEmpty) {
          final firstWithTasks = fromCache.where((s) => s.tasks.isNotEmpty).map((s) => s.projectId);
          _expanded.add(firstWithTasks.isNotEmpty ? firstWithTasks.first : fromCache.first.projectId);
        }
      });
    }

    try {
      final tasks = await boardRepo.listMyTasks();
      if (!mounted) return;
      final byProject = <String, List<TaskItem>>{};
      for (final t in tasks) {
        final pid = t.projectId;
        if (pid == null || pid.isEmpty) continue;
        byProject.putIfAbsent(pid, () => []).add(t);
      }

      final sections = <_ProjectKanbanSection>[];
      for (final p in cubit.state.projects) {
        sections.add(
          await _sectionForProject(
            project: p,
            userId: userId,
            cubit: cubit,
            boardRepo: boardRepo,
            mineByProject: byProject,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _sections
          ..clear()
          ..addAll(sections);
        _allLoaded = true;
        _allError = null;
        if (_expanded.isEmpty && sections.isNotEmpty) {
          final firstWithTasks = sections.where((s) => s.tasks.isNotEmpty).map((s) => s.projectId);
          _expanded.add(firstWithTasks.isNotEmpty ? firstWithTasks.first : sections.first.projectId);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _allLoaded = true;
        if (_sections.isEmpty) _allError = e;
      });
    }
  }

  Future<void> _toggleExpand(String projectId) async {
    final willOpen = !_expanded.contains(projectId);
    setState(() {
      if (willOpen) {
        _expanded.add(projectId);
      } else {
        _expanded.remove(projectId);
      }
    });
    if (!willOpen) return;

    final idx = _sections.indexWhere((s) => s.projectId == projectId);
    if (idx < 0) return;
    if (_sections[idx].columns.isNotEmpty) return;
    if (_loadingExpand.contains(projectId)) return;

    final cubit = context.read<BoardCubit>();
    final boardRepo = context.read<BoardRepository>();
    final userId = cubit.currentUserId;
    final project = cubit.state.projects.where((p) => p.id == projectId).firstOrNull;
    if (project == null || userId == null) return;

    setState(() => _loadingExpand.add(projectId));
    try {
      final section = await _sectionForProject(
        project: project,
        userId: userId,
        cubit: cubit,
        boardRepo: boardRepo,
      );
      if (!mounted) return;
      setState(() {
        final i = _sections.indexWhere((s) => s.projectId == projectId);
        if (i >= 0) _sections[i] = section;
        _loadingExpand.remove(projectId);
      });
    } catch (_) {
      if (mounted) setState(() => _loadingExpand.remove(projectId));
    }
  }

  Future<void> _moveInAllProjects(_ProjectKanbanSection section, TaskItem task, String toStatusId) async {
    if (task.statusId == toStatusId) return;
    final boardRepo = context.read<BoardRepository>();
    final peers = section.tasks.where((t) => t.statusId == toStatusId && t.id != task.id);
    final minPos = peers.isEmpty
        ? 0.0
        : peers.map((t) => t.position).reduce((a, b) => a < b ? a : b);
    final position = peers.isEmpty ? 0.0 : minPos - 1024;

    final nowIso = DateTime.now().toUtc().toIso8601String();
    StatusColumn? target;
    for (final c in section.columns) {
      if (c.id == toStatusId) {
        target = c;
        break;
      }
    }
    // Optimistic local update (timer + disk cache).
    final optimistic = task.copyWith(
      statusId: toStatusId,
      position: position,
      statusEnteredAt: nowIso,
      closedAt: target?.isDone == true ? nowIso : null,
    );
    setState(() {
      final i = _sections.indexWhere((s) => s.projectId == section.projectId);
      if (i < 0) return;
      final nextTasks = _sections[i].tasks.map((t) => t.id == task.id ? optimistic : t).toList();
      _sections[i] = _sections[i].copyWith(tasks: nextTasks);
    });
    final cubit = context.read<BoardCubit>();
    final cached = await cubit.cache.loadBoard(section.projectId);
    if (cached != null) {
      await cubit.cache.saveBoard(
        project: cached.project,
        columns: cached.columns,
        tasks: cached.tasks.map((t) => t.id == task.id ? optimistic : t).toList(),
      );
    }

    try {
      final updated = await boardRepo.moveTask(
        taskId: task.id,
        statusId: toStatusId,
        position: position,
      );
      if (!mounted) return;
      setState(() {
        final i = _sections.indexWhere((s) => s.projectId == section.projectId);
        if (i < 0) return;
        final nextTasks = _sections[i].tasks.map((t) => t.id == updated.id ? updated : t).toList();
        _sections[i] = _sections[i].copyWith(tasks: nextTasks);
      });
      final after = await cubit.cache.loadBoard(section.projectId);
      if (after != null) {
        await cubit.cache.saveBoard(
          project: after.project,
          columns: after.columns,
          tasks: after.tasks.map((t) => t.id == updated.id ? updated : t).toList(),
        );
      }
    } catch (_) {
      if (!mounted) return;
      // Revert via reload.
      await _loadAllProjects();
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _syncPageController(int index, int count) {
    if (count <= 0) return;
    final clamped = index.clamp(0, count - 1);
    if (_pageController == null) {
      _pageController = PageController(
        initialPage: clamped,
        viewportFraction: 0.9,
      );
      _pageIndex = clamped;
      return;
    }
    if (_pageIndex != clamped) {
      _pageIndex = clamped;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController?.hasClients ?? false) {
          _pageController!.jumpToPage(clamped);
        }
      });
    }
  }

  void _backToProjects() {
    context.read<BoardCubit>().clearProject();
    _pageController?.dispose();
    _pageController = null;
    _pageIndex = 0;
    context.go('/projects');
  }

  List<TaskItem> _mineInBoardColumn(BoardState state, String statusId) {
    final userId = context.read<BoardCubit>().currentUserId;
    if (userId == null || userId.isEmpty) return const [];
    final list = state.tasks
        .where((t) => t.statusId == statusId && t.assignees.any((a) => a.id == userId))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return list;
  }

  Future<void> _openTask(TaskItem task, {required String projectId}) async {
    await context.push('/task/${task.id}');
    if (!mounted) return;
    final cubit = context.read<BoardCubit>();
    if (cubit.state.project != null) {
      await cubit.openProject(projectId);
    } else {
      await _loadAllProjects();
    }
  }

  Future<void> _addInProject(String projectId, String statusId) async {
    final cubit = context.read<BoardCubit>();
    await cubit.openProject(projectId);
    if (!mounted) return;
    await context.push('/task-create?status=$statusId');
    if (!mounted) return;
    if (cubit.state.project == null) {
      await _loadAllProjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BoardCubit, BoardState>(
      listener: (context, state) {
        if (state.project == null) {
          if (_bootstrapped) {
            _bootstrapped = false;
            _loadAllProjects();
          }
          return;
        }
        _bootstrapped = true;
        _syncPageController(state.columnIndex, state.columns.length);
      },
      builder: (context, state) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final boardBg = dark ? KanbanColors.boardBgDark : KanbanColors.boardBgLight;
        final project = state.project;

        if (project == null) {
          return _buildAllProjectsScaffold(context, dark: dark, boardBg: boardBg);
        }

        if (state.columns.isNotEmpty && _pageController == null) {
          _syncPageController(state.columnIndex, state.columns.length);
        }

        final userId = context.read<BoardCubit>().currentUserId;
        final cubit = context.read<BoardCubit>();

        return Scaffold(
          backgroundColor: boardBg,
          appBar: TaktAppBar(
            title: project.name,
            onBack: _backToProjects,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Мои задачи',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: dark ? TaktColors.mutedDark : TaktColors.muted,
                  ),
                ),
              ),
              if (userId == null || userId.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Войдите снова, чтобы увидеть назначенные задачи',
                    style: TextStyle(fontSize: 13, color: dark ? TaktColors.mutedDark : TaktColors.muted),
                  ),
                ),
              Expanded(
                child: _pageController == null
                    ? const SizedBox.shrink()
                    : PageView.builder(
                        controller: _pageController,
                        itemCount: state.columns.length,
                        padEnds: false,
                        physics: _dragging
                            ? const NeverScrollableScrollPhysics()
                            : const KanbanPagePhysics(parent: ClampingScrollPhysics()),
                        onPageChanged: (i) {
                          setState(() => _pageIndex = i);
                          cubit.selectColumn(i);
                        },
                        itemBuilder: (context, i) {
                          final col = state.columns[i];
                          final tasks = _mineInBoardColumn(state, col.id);
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: ClampingScrollPhysics(),
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                  child: KanbanColumnPane(
                                    column: col,
                                    tasks: tasks,
                                    dark: dark,
                                    onAdd: () => context.push('/task-create?status=${col.id}'),
                                    onOpenTask: (task) => _openTask(task, projectId: state.project!.id),
                                    onDraggingChanged: (v) => setState(() => _dragging = v),
                                    onTaskDropped: (task) => cubit.moveToColumn(task, col.id),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAllProjectsScaffold(
    BuildContext context, {
    required bool dark,
    required Color boardBg,
  }) {
    final muted = dark ? TaktColors.mutedDark : TaktColors.muted;
    return Scaffold(
      backgroundColor: boardBg,
      appBar: const TaktAppBar(title: 'Мои задачи'),
      body: RefreshIndicator(
        color: dark ? TaktColors.accentDark : TaktColors.accent,
        onRefresh: () => _loadAllProjects(fromUser: true),
        child: _buildAllProjectsBody(dark: dark, muted: muted),
      ),
    );
  }

  Widget _buildAllProjectsBody({required bool dark, required Color muted}) {
    if (!_allLoaded && _sections.isEmpty) {
      return ListView(physics: const AlwaysScrollableScrollPhysics());
    }

    if (_allError != null && _sections.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          Text(
            'Не удалось загрузить задачи',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
            ),
          ),
          const SizedBox(height: 6),
          Text('Потяните вниз, чтобы повторить', style: TextStyle(fontSize: 13, color: muted)),
        ],
      );
    }

    if (_sections.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          Text(
            'Нет проектов',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Создайте проект на главной — назначенные задачи появятся здесь.',
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ],
      );
    }

    final fg = dark ? TaktColors.foregroundDark : TaktColors.graphite;

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
      itemCount: _sections.length,
      itemBuilder: (context, index) {
        final section = _sections[index];
        final open = _expanded.contains(section.projectId);
        final loading = _loadingExpand.contains(section.projectId);
        final total = section.tasks.length;

        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        section.projectName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.15,
                          color: fg,
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _toggleExpand(section.projectId),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$total',
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                            const SizedBox(width: 2),
                            AppIcon(
                              open ? AppIcons.chevronRight : AppIcons.chevronDown,
                              size: 18,
                              color: muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (open) ...[
                if (loading)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Text('Загрузка…', style: TextStyle(fontSize: 13, color: muted)),
                  )
                else if (section.columns.isEmpty || total == 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Text(
                      total == 0 ? 'Нет назначенных задач' : 'Не удалось загрузить столбцы',
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                  )
                else
                  _MyTasksSectionPager(
                    key: ValueKey('pager-${section.projectId}'),
                    columns: section.columns,
                    tasks: section.tasks,
                    dark: dark,
                    dragging: _dragging,
                    onDraggingChanged: (v) => setState(() => _dragging = v),
                    onAdd: (colId) => _addInProject(section.projectId, colId),
                    onOpenTask: (task) => _openTask(task, projectId: section.projectId),
                    onTaskDropped: (task, colId) => _moveInAllProjects(section, task, colId),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Same PageView as [BoardPage]: viewportFraction 0.9, padEnds false, peek next column.
class _MyTasksSectionPager extends StatefulWidget {
  const _MyTasksSectionPager({
    super.key,
    required this.columns,
    required this.tasks,
    required this.dark,
    required this.dragging,
    required this.onDraggingChanged,
    required this.onAdd,
    required this.onOpenTask,
    required this.onTaskDropped,
  });

  final List<StatusColumn> columns;
  final List<TaskItem> tasks;
  final bool dark;
  final bool dragging;
  final ValueChanged<bool> onDraggingChanged;
  final ValueChanged<String> onAdd;
  final ValueChanged<TaskItem> onOpenTask;
  final void Function(TaskItem task, String columnId) onTaskDropped;

  @override
  State<_MyTasksSectionPager> createState() => _MyTasksSectionPagerState();
}

class _MyTasksSectionPagerState extends State<_MyTasksSectionPager> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<TaskItem> _mineIn(String statusId) {
    return widget.tasks.where((t) => t.statusId == statusId).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  double _heightFor(BuildContext context) {
    var maxTasks = 0;
    for (final col in widget.columns) {
      final n = _mineIn(col.id).length;
      if (n > maxTasks) maxTasks = n;
    }
    // header + pads + cards (approx.); cap so the list stays scrollable
    final content = 64.0 + (maxTasks == 0 ? 48.0 : maxTasks * 128.0);
    final maxH = MediaQuery.sizeOf(context).height * 0.62;
    return content.clamp(140.0, maxH);
  }

  @override
  Widget build(BuildContext context) {
    final height = _heightFor(context);
    return SizedBox(
      height: height,
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.columns.length,
        padEnds: false,
        physics: widget.dragging
            ? const NeverScrollableScrollPhysics()
            : const KanbanPagePhysics(parent: ClampingScrollPhysics()),
        itemBuilder: (context, i) {
          final col = widget.columns[i];
          final tasks = _mineIn(col.id);
          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: KanbanColumnPane(
                    column: col,
                    tasks: tasks,
                    dark: widget.dark,
                    onAdd: () => widget.onAdd(col.id),
                    onOpenTask: widget.onOpenTask,
                    onDraggingChanged: widget.onDraggingChanged,
                    onTaskDropped: (task) => widget.onTaskDropped(task, col.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProjectKanbanSection {
  const _ProjectKanbanSection({
    required this.projectId,
    required this.projectName,
    required this.columns,
    required this.tasks,
  });

  final String projectId;
  final String projectName;
  final List<StatusColumn> columns;
  final List<TaskItem> tasks;

  _ProjectKanbanSection copyWith({
    List<StatusColumn>? columns,
    List<TaskItem>? tasks,
  }) {
    return _ProjectKanbanSection(
      projectId: projectId,
      projectName: projectName,
      columns: columns ?? this.columns,
      tasks: tasks ?? this.tasks,
    );
  }
}

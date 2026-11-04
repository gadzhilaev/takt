import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/kanban_colors.dart';
import '../../../core/theme.dart';
import '../../../features/board/cubit/board_cubit.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/kanban_column.dart';
import '../../../shared/widgets/kanban_drag_edge_scroll.dart';
import '../../../shared/widgets/kanban_page_physics.dart';
import '../../../shared/widgets/takt_app_bar.dart';

/// «Мои задачи» только для открытого проекта (Kanban с назначенными на меня).
class MyTasksPage extends StatefulWidget {
  const MyTasksPage({super.key});

  @override
  State<MyTasksPage> createState() => _MyTasksPageState();
}

class _MyTasksPageState extends State<MyTasksPage> {
  PageController? _pageController;
  final GlobalKey _pagerKey = GlobalKey();
  KanbanDragEdgeScroll? _edgeScroll;
  int _pageIndex = 0;
  bool _dragging = false;
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<BoardCubit>();
      if (cubit.state.project == null) {
        _goHome();
        return;
      }
      _syncPageController(cubit.state.columnIndex, cubit.state.columns.length);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _edgeScroll?.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  void _goHome() {
    if (_redirecting) return;
    _redirecting = true;
    context.go('/projects');
  }

  void _setDragging(bool value) {
    setState(() => _dragging = value);
    if (!value) _edgeScroll?.stop();
  }

  void _ensureEdgeScroll(int pageCount) {
    final ctrl = _pageController;
    if (ctrl == null || pageCount <= 0) return;
    if (_edgeScroll == null || _edgeScroll!.pageCount != pageCount) {
      _edgeScroll?.dispose();
      _edgeScroll = KanbanDragEdgeScroll(controller: ctrl, pageCount: pageCount);
    }
  }

  void _onDragPointer(Offset global) {
    final ctx = _pagerKey.currentContext;
    if (ctx == null) return;
    _edgeScroll?.onPointer(global, ctx);
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
    _edgeScroll?.dispose();
    _edgeScroll = null;
    _pageController?.dispose();
    _pageController = null;
    _pageIndex = 0;
    context.go('/projects');
  }

  List<TaskItem> _mineInBoardColumn(BoardState state, String statusId) {
    final userId = context.read<BoardCubit>().currentUserId;
    if (userId == null || userId.isEmpty) return const [];
    return state.tasks
        .where((t) => t.statusId == statusId && t.assignees.any((a) => a.id == userId))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  Future<void> _openTask(TaskItem task, {required String projectId}) async {
    await context.push('/task/${task.id}');
    if (!mounted) return;
    final cubit = context.read<BoardCubit>();
    if (cubit.state.project != null) {
      await cubit.openProject(projectId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BoardCubit, BoardState>(
      listener: (context, state) {
        if (state.project == null) {
          _goHome();
          return;
        }
        _syncPageController(state.columnIndex, state.columns.length);
      },
      builder: (context, state) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final boardBg = dark ? KanbanColors.boardBgDark : KanbanColors.boardBgLight;
        final project = state.project;

        if (project == null) {
          return Scaffold(
            backgroundColor: boardBg,
            body: const SizedBox.shrink(),
          );
        }

        if (state.columns.isNotEmpty && _pageController == null) {
          _syncPageController(state.columnIndex, state.columns.length);
        }

        final userId = context.read<BoardCubit>().currentUserId;
        final cubit = context.read<BoardCubit>();

        return Scaffold(
          backgroundColor: boardBg,
          appBar: TaktAppBar(
            title: 'Мои задачи',
            subtitle: project.name,
            onBack: _backToProjects,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (userId == null || userId.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Войдите снова, чтобы увидеть назначенные задачи',
                    style: TextStyle(
                      fontSize: 13,
                      color: dark ? TaktColors.mutedDark : TaktColors.muted,
                    ),
                  ),
                ),
              Expanded(
                child: _pageController == null
                    ? const SizedBox.shrink()
                    : Builder(
                        builder: (context) {
                          _ensureEdgeScroll(state.columns.length);
                          return PageView.builder(
                            key: _pagerKey,
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
                                      constraints: BoxConstraints(
                                        minHeight: constraints.maxHeight,
                                      ),
                                      child: KanbanColumnPane(
                                        column: col,
                                        tasks: tasks,
                                        dark: dark,
                                        onAdd: () =>
                                            context.push('/task-create?status=${col.id}'),
                                        onOpenTask: (task) =>
                                            _openTask(task, projectId: state.project!.id),
                                        onDraggingChanged: _setDragging,
                                        onDragPointer: _onDragPointer,
                                        onTaskDropped: (task) =>
                                            cubit.moveToColumn(task, col.id),
                                      ),
                                    ),
                                  );
                                },
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
}

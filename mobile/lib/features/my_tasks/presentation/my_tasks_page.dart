import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/kanban_colors.dart';
import '../../../core/theme.dart';
import '../../../features/board/cubit/board_cubit.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/kanban_column.dart';
import '../../../shared/widgets/kanban_page_physics.dart';
import '../../../shared/widgets/takt_app_bar.dart';

/// Same Kanban layout as Home, filtered to tasks assigned to the current user.
class MyTasksPage extends StatefulWidget {
  const MyTasksPage({super.key});

  @override
  State<MyTasksPage> createState() => _MyTasksPageState();
}

class _MyTasksPageState extends State<MyTasksPage> {
  PageController? _pageController;
  int _pageIndex = 0;
  bool _bootstrapped = false;

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
      // Без выбранного проекта «Мои задачи» недоступны — на хаб.
      if (!mounted) return;
      context.go('/projects');
      return;
    }
    if (!mounted) return;
    _bootstrapped = true;
    _syncPageController(cubit.state.columnIndex, cubit.state.columns.length);
    setState(() {});
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

  List<TaskItem> _mineInColumn(BoardState state, String statusId) {
    final userId = context.read<BoardCubit>().currentUserId;
    if (userId == null || userId.isEmpty) return const [];
    final list = state.tasks
        .where((t) => t.statusId == statusId && t.assignees.any((a) => a.id == userId))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BoardCubit, BoardState>(
      listener: (context, state) {
        if (state.project == null && _bootstrapped) {
          context.go('/projects');
          return;
        }
        if (state.project != null) {
          _syncPageController(state.columnIndex, state.columns.length);
        }
      },
      builder: (context, state) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final boardBg = dark ? KanbanColors.boardBgDark : KanbanColors.boardBgLight;
        final project = state.project;

        if (project == null) {
          return Scaffold(
            backgroundColor: boardBg,
            appBar: const TaktAppBar(title: 'Мои задачи'),
            body: const SizedBox.shrink(),
          );
        }

        if (state.columns.isNotEmpty && _pageController == null) {
          _syncPageController(state.columnIndex, state.columns.length);
        }

        final userId = context.read<BoardCubit>().currentUserId;

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
                        physics: const KanbanPagePhysics(parent: ClampingScrollPhysics()),
                        onPageChanged: (i) {
                          setState(() => _pageIndex = i);
                          context.read<BoardCubit>().selectColumn(i);
                        },
                        itemBuilder: (context, i) {
                          final col = state.columns[i];
                          final tasks = _mineInColumn(state, col.id);
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
                                    onOpenTask: (task) async {
                                      final cubit = context.read<BoardCubit>();
                                      final projectId = state.project?.id;
                                      await context.push('/task/${task.id}');
                                      if (!mounted || projectId == null) return;
                                      await cubit.openProject(projectId);
                                    },
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
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/kanban_colors.dart';
import '../../../core/theme.dart';
import '../../../features/notifications/data/notifications_repository.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/kanban_column.dart';
import '../../../shared/widgets/kanban_page_physics.dart';
import '../../../shared/widgets/takt_app_bar.dart';
import '../cubit/board_cubit.dart';

class BoardPage extends StatefulWidget {
  const BoardPage({super.key, this.deepTaskId, this.deepProjectId});

  final String? deepTaskId;
  final String? deepProjectId;

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  PageController? _pageController;
  int _pageIndex = 0;
  int _unread = 0;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _loadUnread();
  }

  Future<void> _bootstrap() async {
    final cubit = context.read<BoardCubit>();
    final prefer = widget.deepProjectId;
    if (prefer != null && prefer.isNotEmpty) {
      await cubit.bootstrap(preferProjectId: prefer);
    } else if (cubit.state.project == null && cubit.state.projects.isEmpty) {
      await cubit.bootstrap();
    }
    if (!mounted) return;
    _bootstrapped = true;
    final state = cubit.state;
    if (state.project == null) {
      context.go('/projects');
      return;
    }
    _syncPageController(state.columnIndex, state.columns.length);
    setState(() {});
    final deepId = widget.deepTaskId;
    if (deepId != null && deepId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.push('/task/$deepId');
      });
    }
  }

  Future<void> _loadUnread() async {
    try {
      final list = await context.read<NotificationsRepository>().list(unreadOnly: true);
      if (mounted) setState(() => _unread = list.length);
    } catch (_) {
      /* ignore */
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

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BoardCubit, BoardState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error!)));
        }
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
          // Редирект на хаб в listener / bootstrap — без спиннера после splash.
          return Scaffold(
            backgroundColor: boardBg,
            appBar: const TaktAppBar(title: 'Доска'),
            body: const SizedBox.shrink(),
          );
        }

        if (state.columns.isNotEmpty && _pageController == null) {
          _syncPageController(state.columnIndex, state.columns.length);
        }

        return Scaffold(
          backgroundColor: boardBg,
          appBar: TaktAppBar(
            title: project.name,
            onBack: _backToProjects,
            actions: [
              IconButton(
                tooltip: 'Уведомления',
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  await context.push('/notifications');
                  _loadUnread();
                },
                icon: Badge(
                  isLabelVisible: _unread > 0,
                  smallSize: 8,
                  backgroundColor: TaktColors.urgent,
                  child: AppIcon(
                    AppIcons.notifications,
                    size: 22,
                    color: dark ? TaktColors.foregroundDark : TaktColors.graphite,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.offline)
                Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Офлайн: показаны последние данные. Изменения временно недоступны.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              Expanded(
                child: _pageController == null
                    ? const SizedBox.shrink()
                    : RefreshIndicator(
                        notificationPredicate: (n) => n.depth == 0 || n.depth == 1,
                        onRefresh: () => context.read<BoardCubit>().refreshBoard(),
                        child: PageView.builder(
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
                            final tasks = state.tasks.where((t) => t.statusId == col.id).toList()
                              ..sort((a, b) => a.position.compareTo(b.position));
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
                                      onOpenTask: (task) => context.push('/task/${task.id}'),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

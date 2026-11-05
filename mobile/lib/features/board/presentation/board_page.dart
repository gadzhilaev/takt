import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/kanban_colors.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/column_color_field.dart' show suggestUnusedColumnColor;
import '../../../shared/widgets/kanban_column.dart';
import '../../../shared/widgets/kanban_drag_edge_scroll.dart';
import '../../../shared/widgets/kanban_page_physics.dart';
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
  final GlobalKey _pagerKey = GlobalKey();
  KanbanDragEdgeScroll? _edgeScroll;
  int _pageIndex = 0;
  bool _bootstrapped = false;
  bool _dragging = false;

  final _newColumnName = TextEditingController();
  bool _addingColumn = false;
  bool _creatingColumn = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
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
      // IndexedStack also mounts Board under /my-tasks|/profile — don't steal navigation.
      final loc = GoRouterState.of(context).matchedLocation;
      if (loc.startsWith('/board')) {
        context.go('/projects');
      }
      return;
    }
    _syncPageController(state.columnIndex, _pageCount(state));
    setState(() {});
    final deepId = widget.deepTaskId;
    if (deepId != null && deepId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.push('/task/$deepId');
      });
    }
  }

  int _pageCount(BoardState state) => state.columns.length + 1;

  @override
  void dispose() {
    _edgeScroll?.dispose();
    _pageController?.dispose();
    _newColumnName.dispose();
    super.dispose();
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

  Future<void> _submitNewColumn() async {
    final name = _newColumnName.text.trim();
    if (name.isEmpty || _creatingColumn) return;
    setState(() => _creatingColumn = true);
    final cubit = context.read<BoardCubit>();
    final color = suggestUnusedColumnColor(cubit.state.columns.map((c) => c.color));
    final col = await cubit.createColumn(name: name, color: color);
    if (!mounted) return;
    setState(() {
      _creatingColumn = false;
      _addingColumn = false;
    });
    if (col == null) return;
    _newColumnName.clear();
    final idx = cubit.state.columns.indexWhere((c) => c.id == col.id);
    if (idx >= 0) {
      _syncPageController(idx, _pageCount(cubit.state));
      setState(() {});
    }
  }

  void _cancelAddColumn() {
    setState(() {
      _addingColumn = false;
      _creatingColumn = false;
      _newColumnName.clear();
    });
  }

  Widget _buildAddColumnPage(BoardState state, bool dark) {
    final border = dark ? TaktColors.borderDark : TaktColors.border;
    final muted = dark ? KanbanColors.descDark : KanbanColors.descLight;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
                child: _addingColumn
                    ? Material(
                        color: dark ? TaktColors.surface2Dark : TaktColors.surface2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(TaktRadii.lg),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: _newColumnName,
                                autofocus: true,
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(
                                  hintText: 'Новый столбец',
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _submitNewColumn(),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  FilledButton(
                                    onPressed: _creatingColumn ? null : _submitNewColumn,
                                    child: Text(_creatingColumn ? '…' : 'Добавить'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: _creatingColumn ? null : _cancelAddColumn,
                                    child: const Text('Отмена'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    : Material(
                        color: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(TaktRadii.lg),
                          side: BorderSide(color: border, style: BorderStyle.solid),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(TaktRadii.lg),
                          onTap: () => setState(() => _addingColumn = true),
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: Text(
                                  '+ Добавить столбец',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BoardCubit, BoardState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error!)));
        }
        if (state.project == null && _bootstrapped) {
          final loc = GoRouterState.of(context).matchedLocation;
          if (loc.startsWith('/board')) {
            context.go('/projects');
          }
          return;
        }
        if (state.project != null) {
          _syncPageController(state.columnIndex, _pageCount(state));
        }
      },
      builder: (context, state) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final boardBg = dark ? KanbanColors.boardBgDark : KanbanColors.boardBgLight;
        final project = state.project;

        if (project == null) {
          return ColoredBox(color: boardBg, child: const SizedBox.expand());
        }

        final pages = _pageCount(state);
        if (state.columns.isNotEmpty && _pageController == null) {
          _syncPageController(state.columnIndex, pages);
        }

        return ColoredBox(
          color: boardBg,
          child: _pageController == null
              ? const SizedBox.shrink()
              : RefreshIndicator(
                  notificationPredicate: (n) => n.depth == 0 || n.depth == 1,
                  onRefresh: () => context.read<BoardCubit>().refreshBoard(),
                  child: Builder(
                    builder: (context) {
                      _ensureEdgeScroll(pages);
                      return PageView.builder(
                        key: _pagerKey,
                        controller: _pageController,
                        itemCount: pages,
                        padEnds: false,
                        physics: _dragging
                            ? const NeverScrollableScrollPhysics()
                            : const KanbanPagePhysics(parent: ClampingScrollPhysics()),
                        onPageChanged: (i) {
                          setState(() {
                            _pageIndex = i;
                            if (i < state.columns.length && _addingColumn) {
                              _addingColumn = false;
                              _newColumnName.clear();
                            }
                          });
                          if (i < state.columns.length) {
                            context.read<BoardCubit>().selectColumn(i);
                          }
                        },
                        itemBuilder: (context, i) {
                          if (i >= state.columns.length) {
                            return _buildAddColumnPage(state, dark);
                          }
                          final col = state.columns[i];
                          final tasks = state.tasks
                              .where((t) => t.statusId == col.id)
                              .toList()
                            ..sort((a, b) => a.position.compareTo(b.position));
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
                                    onOpenTask: (task) => context.push('/task/${task.id}'),
                                    onDraggingChanged: _setDragging,
                                    onDragPointer: _onDragPointer,
                                    onTaskDropped: (task) => context
                                        .read<BoardCubit>()
                                        .moveToColumn(task, col.id),
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
        );
      },
    );
  }
}

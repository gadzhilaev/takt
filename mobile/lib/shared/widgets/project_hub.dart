import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../models/models.dart';
import '../project_visibility.dart';
import 'app_icon.dart';
import 'project_actions.dart';

/// Project list: tap opens board; ⋮ opens actions (members / rename / delete|leave).
class ProjectHub extends StatefulWidget {
  const ProjectHub({
    super.key,
    required this.projects,
    required this.onOpenProject,
    required this.onCreateProject,
    this.currentUserId,
    this.onProjectsChanged,
    this.onRefresh,
  });

  final List<Project> projects;
  final String? currentUserId;
  final ValueChanged<String> onOpenProject;
  final VoidCallback onCreateProject;
  final VoidCallback? onProjectsChanged;
  final Future<void> Function()? onRefresh;

  @override
  State<ProjectHub> createState() => _ProjectHubState();
}

class _ProjectHubState extends State<ProjectHub> {
  List<Project> get _visible => taktVisibleProjects(widget.projects);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final projects = _visible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Мои проекты',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: dark ? TaktColors.mutedDark : TaktColors.muted,
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onCreateProject,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: AppIcon(
                    AppIcons.add,
                    size: 20,
                    color: dark ? TaktColors.accentDark : TaktColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: projects.isEmpty
              ? Center(
                  child: Text(
                    'Нет доступных проектов',
                    style: TextStyle(color: dark ? TaktColors.mutedDark : TaktColors.muted),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: widget.onRefresh ?? () async {},
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(8, 4, 4, 16),
                    itemCount: projects.length,
                    itemBuilder: (context, i) {
                      final p = projects[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => widget.onOpenProject(p.id),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(8, 12, 4, 12),
                                  child: Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -0.2,
                                      color: dark
                                          ? TaktColors.foregroundDark
                                          : TaktColors.graphite,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Ещё',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => showProjectActionsMenu(
                                context,
                                project: p,
                                currentUserId: widget.currentUserId,
                                onChanged: widget.onProjectsChanged,
                              ),
                              icon: AppIcon(
                                AppIcons.more,
                                size: 20,
                                color: dark ? TaktColors.mutedDark : TaktColors.muted,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

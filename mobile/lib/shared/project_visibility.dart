import 'models/models.dart';

/// Playwright / CI projects must not appear in normal product UI.
bool taktIsTestProject(Project project) {
  final name = project.name.trim().toLowerCase();
  final desc = (project.description ?? '').toLowerCase();
  if (name.startsWith('[e2e]')) return true;
  if (name.contains('playwright')) return true;
  if (desc.contains('[e2e]')) return true;
  return false;
}

List<Project> taktVisibleProjects(Iterable<Project> projects) =>
    projects.where((p) => !taktIsTestProject(p)).toList(growable: false);

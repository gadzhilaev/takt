import type { ProjectMember, Task } from "@/lib/types";

/** Tasks where `userId` is among assignees (multi-assignee → appears for each). */
export function tasksForMember(tasks: Task[], userId: string): Task[] {
  return tasks.filter((t) => t.assignees.some((a) => a.id === userId));
}

export function isProjectMember(members: ProjectMember[], userId: string | undefined | null): boolean {
  if (!userId) return false;
  return members.some((m) => m.user_id === userId);
}

export function memberTasksTitle(
  members: ProjectMember[],
  selectedUserId: string,
  currentUserId: string
): string {
  if (selectedUserId === currentUserId) return "Мои задачи";
  const m = members.find((x) => x.user_id === selectedUserId);
  return m ? `Задачи ${m.name}` : "Задачи сотрудника";
}

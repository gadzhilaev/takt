import { describe, expect, it } from "vitest";
import { isProjectMember, memberTasksTitle, tasksForMember } from "./member-tasks";
import type { ProjectMember, Task } from "./types";

const members: ProjectMember[] = [
  { user_id: "u1", role: "admin", name: "Я Пользователь", email: "a@a.ru", avatar_url: null },
  { user_id: "u2", role: "member", name: "Кадачиев Алибек", email: "b@b.ru", avatar_url: null },
];

function task(partial: Partial<Task> & Pick<Task, "id" | "assignees">): Task {
  return {
    project_id: "p1",
    parent_id: null,
    title: "T",
    description: null,
    status_id: "s1",
    priority: "medium",
    author_id: "u1",
    due_date: null,
    closed_at: null,
    position: 0,
    created_at: "",
    updated_at: "",
    labels: [],
    checklist_done: 0,
    checklist_total: 0,
    ...partial,
  };
}

describe("member-tasks", () => {
  it("filters by assignee and keeps multi-assignee tasks for each", () => {
    const shared = task({
      id: "1",
      assignees: [
        { id: "u1", name: "A", avatar_url: null },
        { id: "u2", name: "B", avatar_url: null },
      ],
    });
    const onlyU2 = task({
      id: "2",
      assignees: [{ id: "u2", name: "B", avatar_url: null }],
    });
    expect(tasksForMember([shared, onlyU2], "u1").map((t) => t.id)).toEqual(["1"]);
    expect(tasksForMember([shared, onlyU2], "u2").map((t) => t.id)).toEqual(["1", "2"]);
  });

  it("detects membership and builds titles", () => {
    expect(isProjectMember(members, "u1")).toBe(true);
    expect(isProjectMember(members, "x")).toBe(false);
    expect(memberTasksTitle(members, "u1", "u1")).toBe("Мои задачи");
    expect(memberTasksTitle(members, "u2", "u1")).toBe("Задачи Кадачиев Алибек");
  });
});

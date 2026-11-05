export type PlatformRole = "none" | "support" | "moderator" | "admin" | "super_admin";

export type User = {
  id: string;
  email: string;
  name: string;
  role: "admin" | "member";
  /** Platform console access (`/admin`). Independent of project role. */
  platform_role?: PlatformRole | string;
  avatar_url: string | null;
  must_change_password: boolean;
};

export function hasPlatformAccess(role: string | null | undefined): boolean {
  return Boolean(role && role !== "none");
}

export function platformRoleLabel(role: string | null | undefined): string {
  switch (role) {
    case "support":
      return "Поддержка";
    case "moderator":
      return "Модератор";
    case "admin":
      return "Администратор";
    case "super_admin":
      return "Суперадмин";
    case "none":
    case null:
    case undefined:
    case "":
      return "Пользователь";
    default:
      return "Пользователь";
  }
}

export function loginMethodsLabel(methods: string[] | null | undefined): string {
  if (!methods?.length) return "—";
  const map: Record<string, string> = {
    email: "Email",
    vk: "VK ID",
    yandex: "Яндекс",
    apple: "Apple",
  };
  return methods.map((m) => map[m] ?? m).join(", ");
}

export type Status = {
  id: string;
  name: string;
  color: string;
  position: number;
  is_done: boolean;
  project_id?: string | null;
};

export type ProjectMember = {
  user_id: string;
  role: "admin" | "member" | "viewer";
  name: string;
  email: string;
  avatar_url: string | null;
};

export type Project = {
  id: string;
  name: string;
  description: string | null;
  color: string;
  icon: string;
  is_default: boolean;
  is_archived: boolean;
  is_demo?: boolean;
  created_at: string;
  updated_at: string;
  members: ProjectMember[];
  progress?: { total: number; done: number; percent: number } | null;
};

export type TaskAttachment = {
  id: string;
  filename: string;
  content_type: string;
  size_bytes: number;
  is_image: boolean;
  url: string;
  preview_url: string | null;
  created_at: string;
};

export type Task = {
  id: string;
  project_id: string | null;
  parent_id: string | null;
  title: string;
  description: string | null;
  status_id: string;
  status?: Status;
  priority: "low" | "medium" | "high" | "urgent";
  author_id: string;
  author?: { id: string; name: string; avatar_url: string | null };
  due_date: string | null;
  closed_at: string | null;
  status_entered_at?: string;
  archived_at?: string | null;
  position: number;
  created_at: string;
  updated_at: string;
  assignees: { id: string; name: string; avatar_url: string | null }[];
  labels: { id: string; name: string; color: string }[];
  checklist_items?: { id: string; title: string; is_done: boolean; position: number }[];
  checklist_done: number;
  checklist_total: number;
  comment_count?: number;
  subtask_total?: number;
  subtask_done?: number;
  attachments?: TaskAttachment[];
};

export type NotificationItem = {
  id: string;
  kind: string;
  title: string;
  body: string | null;
  task_id: string | null;
  project_id: string | null;
  project_name?: string | null;
  is_read: boolean;
  created_at: string;
};

export type User = {
  id: string;
  email: string;
  name: string;
  role: "admin" | "member";
  avatar_url: string | null;
  must_change_password: boolean;
};

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
  created_at: string;
  updated_at: string;
  members: ProjectMember[];
  progress?: { total: number; done: number; percent: number } | null;
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
};

export type NotificationItem = {
  id: string;
  kind: string;
  title: string;
  body: string | null;
  task_id: string | null;
  project_id: string | null;
  is_read: boolean;
  created_at: string;
};

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
};

export type Task = {
  id: string;
  title: string;
  description: string | null;
  status_id: string;
  status?: Status;
  priority: "low" | "medium" | "high" | "urgent";
  author_id: string;
  author?: { id: string; name: string; avatar_url: string | null };
  due_date: string | null;
  closed_at: string | null;
  position: number;
  created_at: string;
  updated_at: string;
  assignees: { id: string; name: string; avatar_url: string | null }[];
  labels: { id: string; name: string; color: string }[];
  checklist_done: number;
  checklist_total: number;
};

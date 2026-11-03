/** Canonical workspace paths (web). Old URLs redirect via next.config. */
export const paths = {
  home: "/",
  login: "/login",
  register: "/register",
  forgotPassword: "/forgot-password",
  changePassword: "/change-password",
  app: "/app",
  projects: "/app/projects",
  project: (id: string) => `/app/projects/${id}`,
  projectTask: (projectId: string, taskId: string) =>
    `/app/projects/${projectId}?task=${taskId}`,
  myTasks: "/app/my-tasks",
  profile: "/app/profile",
  /** Opens ProfileDrawer; prefer last project so hub never shows empty redirect. */
  profileDrawer: "/app/projects?profile=1",
  notifications: "/app/inbox",
  admin: "/app/admin",
  adminSettings: "/app/admin/settings",
  platformAdmin: "/admin",
  task: (id: string) => `/app/tasks/${id}`,
  invite: (token: string) => `/invite/${token}`,
} as const;

export function loginWithNext(nextPath?: string | null) {
  if (!nextPath || nextPath === "/" || nextPath.startsWith("/login")) return paths.login;
  return `${paths.login}?next=${encodeURIComponent(nextPath)}`;
}

/** Return to the in-app profile drawer, optionally with a flash message. */
export function profileDrawerPath(message?: string | null) {
  let base: string = paths.projects;
  if (typeof window !== "undefined") {
    try {
      const last = localStorage.getItem("takt:lastProjectId");
      if (last) base = paths.project(last);
    } catch {
      /* ignore */
    }
  }
  const q = new URLSearchParams({ profile: "1" });
  if (message) q.set("message", message);
  return `${base}?${q.toString()}`;
}

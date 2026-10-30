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
  notifications: "/app/inbox",
  admin: "/app/admin",
  adminSettings: "/app/admin/settings",
  platformAdmin: "/admin",
  task: (id: string) => `/app/tasks/${id}`,
} as const;

export function loginWithNext(nextPath?: string | null) {
  if (!nextPath || nextPath === "/" || nextPath.startsWith("/login")) return paths.login;
  return `${paths.login}?next=${encodeURIComponent(nextPath)}`;
}

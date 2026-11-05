"use client";

import { AppIcon } from "@/components/ui/app-icon";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useMemo, useState } from "react";
import { api } from "@/lib/api";
import { hasPlatformAccess, type Project, type User as AppUser } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { UserAvatar } from "@/components/user-avatar";
import { BrandLogo, BrandMark } from "@/components/brand-mark";
import { Dialog } from "@/components/ui/dialog";
import { NotificationToasts } from "@/components/notification-toasts";
import { NotificationsDrawer } from "@/components/notifications-drawer";
import { NotificationsMenu } from "@/components/notifications-menu";
import { ProfileDrawer } from "@/components/profile-drawer";
import { PushPermissionPrompt } from "@/components/push-permission-prompt";
import { ThemeMenu } from "@/components/ui/theme-menu";
import { clearLastProjectId, getLastProjectId, setLastProjectId } from "@/lib/last-project";
import { paths } from "@/lib/paths";
import { cn } from "@/lib/utils";

type InviteItem = {
  id: string;
  project_id: string;
  project_name: string | null;
  email: string | null;
  status: string;
  invited_by_name: string | null;
  token?: string | null;
};

type LeaveRequest = {
  id: string;
  project_id: string;
  user_id: string;
  user_name: string;
  avatar_url: string | null;
  status: string;
};

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const qc = useQueryClient();
  const [mobileOpen, setMobileOpen] = useState(false);
  const [sidebarHidden, setSidebarHidden] = useState(false);
  const [profileOpen, setProfileOpen] = useState(false);
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const [createOpen, setCreateOpen] = useState(false);
  const [menuProjectId, setMenuProjectId] = useState<string | null>(null);
  const [membersProjectId, setMembersProjectId] = useState<string | null>(null);
  const [renameProjectId, setRenameProjectId] = useState<string | null>(null);
  const [renameValue, setRenameValue] = useState("");
  const [inviteOpen, setInviteOpen] = useState<string | null>(null);
  const [projectName, setProjectName] = useState("");
  const [projectDesc, setProjectDesc] = useState("");
  const [inviteEmail, setInviteEmail] = useState("");
  const [inviteNote, setInviteNote] = useState("");
  const [linkBusy, setLinkBusy] = useState(false);
  const [copiedHint, setCopiedHint] = useState("");

  const { data } = useQuery({
    queryKey: ["me"],
    queryFn: () => api<{ user: AppUser }>("/api/v1/auth/me"),
    staleTime: 60_000,
  });
  const { data: projectsData } = useQuery({
    queryKey: ["projects"],
    queryFn: () => api<{ items: Project[] }>("/api/v1/projects"),
    staleTime: 20_000,
  });
  const { data: invitesData, refetch: refetchInvites } = useQuery({
    queryKey: ["my-invites"],
    queryFn: () => api<{ items: InviteItem[] }>("/api/v1/invites/mine"),
    staleTime: 15_000,
  });
  const user = data?.user;
  const projects = useMemo(() => projectsData?.items ?? [], [projectsData?.items]);
  const myInvites = invitesData?.items ?? [];

  const currentProjectId = useMemo(() => {
    const m = pathname.match(/^\/app\/projects\/([^/?#]+)/);
    return m?.[1] ?? null;
  }, [pathname]);

  useEffect(() => {
    if (currentProjectId) setLastProjectId(currentProjectId);
  }, [currentProjectId]);

  useEffect(() => {
    try {
      setSidebarHidden(localStorage.getItem("takt:sidebarHidden") === "1");
    } catch {
      /* ignore */
    }
  }, []);

  function toggleSidebarHidden() {
    setSidebarHidden((prev) => {
      const next = !prev;
      try {
        localStorage.setItem("takt:sidebarHidden", next ? "1" : "0");
      } catch {
        /* ignore */
      }
      return next;
    });
  }

  // Старый id в URL после wipe / потери доступа — на главный экран проектов.
  useEffect(() => {
    if (!projectsData || !currentProjectId) return;
    if (projects.some((p) => p.id === currentProjectId)) return;
    clearLastProjectId();
    router.replace("/app/projects");
  }, [projectsData, projects, currentProjectId, router]);

  useEffect(() => {
    if (!pathname.startsWith("/app/inbox")) return;
    setNotificationsOpen(true);
    setMobileOpen(false);
    const fallback = getLastProjectId();
    const valid = fallback && projects.some((p) => p.id === fallback) ? fallback : null;
    router.replace(valid ? `/app/projects/${valid}` : "/app/projects");
  }, [pathname, router, projects]);

  // /app/projects без id — сразу на последнюю/дефолтную доску (не оставляем «Открываем доску…»).
  useEffect(() => {
    if (pathname !== "/app/projects") return;
    if (!projectsData) return;
    if (typeof window === "undefined") return;
    const sp = new URLSearchParams(window.location.search);
    if (sp.get("browse") === "1" || sp.get("new") === "1") return;
    if (!projects.length) return;
    const last = getLastProjectId();
    const lastProject = last ? projects.find((p) => p.id === last) : undefined;
    const college = projects.find((p) => p.name === "Колледж ДГУ");
    const target =
      (lastProject && lastProject.name !== "Демо-доска" ? lastProject : undefined) ||
      college ||
      projects.find((p) => p.is_default) ||
      projects[0];
    if (!target) return;
    setLastProjectId(target.id);
    const next = new URLSearchParams();
    if (sp.get("profile") === "1") next.set("profile", "1");
    const message = sp.get("message");
    if (message) next.set("message", message);
    const qs = next.toString();
    router.replace(qs ? `/app/projects/${target.id}?${qs}` : `/app/projects/${target.id}`);
  }, [pathname, projectsData, projects, router]);

  // ?profile=1 — открыть drawer профиля (в т.ч. возврат из «Задать пароль»).
  useEffect(() => {
    if (typeof window === "undefined") return;
    if (!pathname.startsWith("/app/")) return;
    const sp = new URLSearchParams(window.location.search);
    if (sp.get("profile") !== "1") return;
    setProfileOpen(true);
    setMobileOpen(false);
    void qc.invalidateQueries({ queryKey: ["me"] });
    sp.delete("profile");
    sp.delete("message");
    const qs = sp.toString();
    router.replace(qs ? `${pathname}?${qs}` : pathname);
  }, [pathname, router, qc]);

  const createProject = useMutation({
    mutationFn: () =>
      api<{ project: Project }>("/api/v1/projects", {
        method: "POST",
        json: {
          name: projectName.trim(),
          description: projectDesc.trim() || null,
          color: "#315F72",
          icon: "folder",
          member_ids: [],
        },
      }),
    onSuccess: (res) => {
      qc.invalidateQueries({ queryKey: ["projects"] });
      setCreateOpen(false);
      setProjectName("");
      setProjectDesc("");
      setLastProjectId(res.project.id);
      setMobileOpen(false);
      router.push(`/app/projects/${res.project.id}`);
    },
  });

  const inviteMut = useMutation({
    mutationFn: (projectId: string) =>
      api<{ invite: InviteItem; note?: string }>(`/api/v1/projects/${projectId}/invites`, {
        method: "POST",
        json: { email: inviteEmail.trim() },
      }),
    onSuccess: async (res) => {
      setInviteNote(res.note || "Приглашение создано");
      setInviteEmail("");
      qc.invalidateQueries({ queryKey: ["project-invites", inviteOpen] });
      qc.invalidateQueries({ queryKey: ["project", inviteOpen] });
      qc.invalidateQueries({ queryKey: ["projects"] });
      if (res.invite.token) {
        await copyInviteLink(res.invite.token);
      }
    },
  });

  const { data: pendingInvites } = useQuery({
    queryKey: ["project-invites", inviteOpen],
    enabled: !!inviteOpen,
    queryFn: () => api<{ items: InviteItem[] }>(`/api/v1/projects/${inviteOpen}/invites`),
  });

  function inviteUrl(token: string) {
    if (typeof window === "undefined") return paths.invite(token);
    return `${window.location.origin}${paths.invite(token)}`;
  }

  async function copyInviteLink(token: string) {
    const url = inviteUrl(token);
    try {
      await navigator.clipboard.writeText(url);
      setCopiedHint("Ссылка скопирована");
      window.setTimeout(() => setCopiedHint(""), 2500);
    } catch {
      setCopiedHint(url);
    }
  }

  async function ensureOpenInviteLink() {
    if (!inviteOpen) return;
    setLinkBusy(true);
    setInviteNote("");
    try {
      const existing = pendingInvites?.items.find((i) => !i.email && i.token);
      if (existing?.token) {
        await copyInviteLink(existing.token);
        return;
      }
      const res = await api<{ invite: InviteItem; note?: string }>(
        `/api/v1/projects/${inviteOpen}/invites`,
        { method: "POST", json: {} }
      );
      qc.invalidateQueries({ queryKey: ["project-invites", inviteOpen] });
      if (res.invite.token) await copyInviteLink(res.invite.token);
      setInviteNote(res.note || "");
    } catch (e) {
      setInviteNote(e instanceof Error ? e.message : "Не удалось создать ссылку");
    } finally {
      setLinkBusy(false);
    }
  }

  function openProject(id: string) {
    setLastProjectId(id);
    setMobileOpen(false);
    router.push(`/app/projects/${id}`);
  }

  const membersProject = useMemo(
    () => projects.find((p) => p.id === membersProjectId) ?? null,
    [projects, membersProjectId]
  );
  const renameProject = useMemo(
    () => projects.find((p) => p.id === renameProjectId) ?? null,
    [projects, renameProjectId]
  );
  async function removeMember(projectId: string, member: Project["members"][number]) {
    if (!confirm(`Убрать ${member.name} из проекта?`)) return;
    await api(`/api/v1/projects/${projectId}/members/${member.user_id}`, { method: "DELETE" });
    qc.invalidateQueries({ queryKey: ["projects"] });
    qc.invalidateQueries({ queryKey: ["leave-requests", projectId] });
  }

  async function leaveProject(projectId: string, projectName: string) {
    if (
      !confirm(
        `Вы выйдете из проекта «${projectName}» и больше не будете видеть его задачи и доску. Продолжить?`
      )
    ) {
      return;
    }
    await api(`/api/v1/projects/${projectId}/leave`, { method: "POST" });
    qc.invalidateQueries({ queryKey: ["projects"] });
    if (currentProjectId === projectId) {
      clearLastProjectId();
      router.push("/app/projects");
    }
  }

  async function deleteProject(project: Project) {
    if (project.is_default) {
      alert("Нельзя удалить проект «Общее»");
      return;
    }
    if (
      !confirm(
        `Если удалите проект «${project.name}», все задачи, столбцы и участники будут удалены безвозвратно. Удалить?`
      )
    ) {
      return;
    }
    await api(`/api/v1/projects/${project.id}`, { method: "DELETE" });
    qc.invalidateQueries({ queryKey: ["projects"] });
    if (currentProjectId === project.id) {
      clearLastProjectId();
      router.push("/app/projects");
    }
  }

  async function decideLeave(projectId: string, requestId: string, approve: boolean) {
    await api(
      `/api/v1/projects/${projectId}/leave-requests/${requestId}/${approve ? "approve" : "reject"}`,
      { method: "POST" }
    );
    qc.invalidateQueries({ queryKey: ["projects"] });
    qc.invalidateQueries({ queryKey: ["leave-requests", projectId] });
    qc.invalidateQueries({ queryKey: ["notifications"] });
  }

  async function saveRename() {
    if (!renameProject) return;
    const name = renameValue.trim();
    if (!name) return;
    await api(`/api/v1/projects/${renameProject.id}`, {
      method: "PATCH",
      json: { name },
    });
    setRenameProjectId(null);
    qc.invalidateQueries({ queryKey: ["projects"] });
  }

  const Sidebar = (
    <aside className="flex h-full w-[13.75rem] shrink-0 flex-col border-r border-hairline bg-[var(--sidebar,var(--surface))] xl:w-[19.5rem]">
      <div className="flex shrink-0 items-center justify-between gap-1 px-2.5 py-3 xl:gap-2 xl:px-4 xl:py-4">
        <Link href="/app/projects" className="inline-flex min-w-0" aria-label="Takt">
          <BrandLogo className="h-6 xl:h-7" />
        </Link>
        <div className="flex items-center gap-0.5">
          <NotificationsMenu onOpen={() => setNotificationsOpen(true)} />
          <ThemeMenu />
          <button
            type="button"
            className="hidden h-8 w-8 items-center justify-center rounded-[var(--radius)] text-muted hover:bg-[var(--surface-2)] hover:text-foreground lg:inline-flex"
            aria-label="Скрыть боковую панель"
            title="Скрыть боковую панель"
            onClick={toggleSidebarHidden}
          >
            <AppIcon name="chevron-left" size={18} />
          </button>
        </div>
      </div>

      {myInvites.length > 0 && (
        <div className="mx-3 mb-3 space-y-2 rounded-[var(--radius)] border border-hairline bg-[var(--surface-2)] p-2.5">
          <p className="text-[12px] font-semibold uppercase tracking-wide text-muted">Приглашения</p>
          {myInvites.map((inv) => (
            <div key={inv.id} className="space-y-1.5">
              <p className="text-[13px] leading-snug">
                <span className="font-medium">{inv.project_name}</span>
                {inv.invited_by_name ? ` · ${inv.invited_by_name}` : ""}
              </p>
              <div className="flex gap-1">
                <Button
                  size="sm"
                  className="h-8 px-2.5 text-[13px]"
                  onClick={async () => {
                    const res = await api<{ project_id: string }>(`/api/v1/invites/${inv.id}/accept`, {
                      method: "POST",
                    });
                    await qc.invalidateQueries({ queryKey: ["projects"] });
                    await refetchInvites();
                    openProject(res.project_id);
                  }}
                >
                  Принять
                </Button>
                <Button
                  size="sm"
                  variant="ghost"
                  className="h-8 px-2.5 text-[13px]"
                  onClick={async () => {
                    await api(`/api/v1/invites/${inv.id}/decline`, { method: "POST" });
                    refetchInvites();
                  }}
                >
                  Отклонить
                </Button>
              </div>
            </div>
          ))}
        </div>
      )}

      <div className="flex shrink-0 items-center justify-between gap-1 px-2 pb-1.5 pt-0.5 xl:gap-2 xl:px-3">
        <p className="section-label truncate px-1 xl:px-1.5">Мои проекты</p>
        <button
          type="button"
          className="inline-flex h-8 w-8 items-center justify-center rounded-[var(--radius)] text-[var(--accent)] hover:bg-[var(--accent-soft)]"
          aria-label="Создать проект"
          title="Создать"
          onClick={() => setCreateOpen(true)}
        >
          <AppIcon name="add" size={18} />
        </button>
      </div>

      <nav className="min-h-0 flex-1 space-y-0.5 overflow-y-auto overscroll-contain px-2 pb-3" aria-label="Проекты">
        {projects.map((p) => {
          const active = p.id === currentProjectId;
          const menuOpen = menuProjectId === p.id;
          const isOwner = p.members.some((m) => m.user_id === user?.id && m.role === "admin");
          return (
            <div key={p.id} className="relative rounded-[var(--radius)]">
              <div
                className={cn(
                  "flex items-center gap-0.5 rounded-[var(--radius)] px-1 py-0.5",
                  active && "bg-[var(--surface-2)]"
                )}
              >
                <button
                  type="button"
                  className={cn(
                    "min-w-0 flex-1 truncate px-2 py-2 text-left text-[15px] leading-snug",
                    active ? "font-semibold text-foreground" : "font-medium text-[var(--muted-fg)] hover:text-foreground"
                  )}
                  onClick={() => openProject(p.id)}
                >
                  {p.name}
                </button>
                <button
                  type="button"
                  className="flex h-8 w-8 shrink-0 items-center justify-center rounded-[var(--radius)] text-muted hover:bg-[var(--surface)] hover:text-foreground"
                  aria-label={`Действия «${p.name}»`}
                  title="Ещё"
                  onClick={(e) => {
                    e.stopPropagation();
                    setMenuProjectId(menuOpen ? null : p.id);
                  }}
                >
                  <AppIcon name="more" size={16} />
                </button>
              </div>
              {menuOpen && (
                <>
                  <button
                    type="button"
                    className="fixed inset-0 z-40 cursor-default"
                    aria-label="Закрыть меню"
                    onClick={() => setMenuProjectId(null)}
                  />
                  <div className="absolute right-1 top-9 z-50 w-[17.5rem] rounded-[var(--radius)] border border-hairline bg-[var(--surface-2)] py-1.5 shadow-md">
                    <button
                      type="button"
                      className="flex w-full items-center gap-3 px-3 py-2.5 text-left text-[15px] font-medium hover:bg-[var(--surface)]"
                      onClick={() => {
                        setMenuProjectId(null);
                        setMembersProjectId(p.id);
                      }}
                    >
                      <AppIcon name="profile" size={18} className="shrink-0 text-muted" />
                      <span className="min-w-0 flex-1">Участники</span>
                      <MemberAvatarStack members={p.members} />
                    </button>
                    {isOwner && (
                      <button
                        type="button"
                        className="flex w-full items-center gap-3 px-3 py-2.5 text-left text-[15px] font-medium hover:bg-[var(--surface)]"
                        onClick={() => {
                          setMenuProjectId(null);
                          setRenameValue(p.name);
                          setRenameProjectId(p.id);
                        }}
                      >
                        <AppIcon name="edit" size={18} className="shrink-0 text-muted" />
                        Переименовать
                      </button>
                    )}
                    <button
                      type="button"
                      className="flex w-full items-center gap-3 px-3 py-2.5 text-left text-[15px] font-medium text-[var(--danger)] hover:bg-[var(--danger-soft)]"
                      onClick={() => {
                        setMenuProjectId(null);
                        if (isOwner) void deleteProject(p);
                        else void leaveProject(p.id, p.name);
                      }}
                    >
                      <AppIcon name="delete" size={18} className="shrink-0" />
                      Удалить
                    </button>
                  </div>
                </>
              )}
            </div>
          );
        })}
        {!projects.length && <p className="px-2.5 py-2 text-[13px] text-muted">Пока нет проектов</p>}
      </nav>

      <div className="shrink-0 space-y-1 border-t border-hairline p-2.5">
        {user && hasPlatformAccess(user.platform_role) && (
          <Link
            href="/admin"
            className="flex w-full items-center gap-2 rounded-[var(--radius)] px-2 py-2 text-[13px] font-medium text-[var(--accent)] hover:bg-[var(--accent-soft)] xl:text-[14px]"
            title="Админка платформы"
          >
            <AppIcon name="settings" size={18} />
            <span className="truncate">Админка платформы</span>
          </Link>
        )}
        {user && (
          <button
            type="button"
            className="flex w-full items-center gap-2.5 rounded-[var(--radius)] px-1.5 py-2 text-left hover:bg-[var(--surface-2)]"
            onClick={() => setProfileOpen(true)}
          >
            <UserAvatar name={user.name} avatarUrl={user.avatar_url} size={9} />
            <span className="min-w-0 flex-1">
              <span className="block truncate text-[13px] font-medium leading-tight xl:text-[14px]">{user.name}</span>
              <span className="hidden text-[12px] text-muted xl:block">Профиль и настройки</span>
            </span>
            <AppIcon name="settings" size={16} className="hidden shrink-0 text-muted xl:block" />
          </button>
        )}
      </div>
    </aside>
  );

  return (
    <div className="flex h-dvh overflow-hidden">
      {!sidebarHidden && (
        <div className="sticky top-0 hidden h-dvh shrink-0 self-start lg:block">{Sidebar}</div>
      )}
      {mobileOpen && (
        <div className="fixed inset-0 z-50 flex lg:hidden">
          <div className="absolute inset-0 bg-black/30" onClick={() => setMobileOpen(false)} aria-hidden />
          <div className="relative z-10 h-full">{Sidebar}</div>
        </div>
      )}

      <div className="flex min-h-0 min-w-0 flex-1 flex-col">
        <header className="z-30 flex h-11 shrink-0 items-center gap-2 border-b border-hairline bg-[var(--surface)] px-3 lg:hidden">
          <Button variant="ghost" size="icon" aria-label="Меню" onClick={() => setMobileOpen(true)}>
            <AppIcon name="menu" size={16} />
          </Button>
          <BrandMark className="h-6" />
          <span className="min-w-0 flex-1 truncate text-sm font-semibold">
            {projects.find((p) => p.id === currentProjectId)?.name || "Takt"}
          </span>
          <NotificationsMenu onOpen={() => setNotificationsOpen(true)} />
          <ThemeMenu />
        </header>
        {sidebarHidden && (
          <div className="z-20 hidden shrink-0 items-center gap-2 border-b border-hairline bg-[var(--surface)] px-3 py-1.5 lg:flex">
            <Button
              variant="ghost"
              size="icon"
              aria-label="Показать боковую панель"
              title="Показать боковую панель"
              onClick={toggleSidebarHidden}
            >
              <AppIcon name="menu" size={16} />
            </Button>
            <BrandMark className="h-6" />
            <span className="min-w-0 flex-1 truncate text-sm font-semibold">
              {projects.find((p) => p.id === currentProjectId)?.name || "Takt"}
            </span>
            <NotificationsMenu onOpen={() => setNotificationsOpen(true)} />
            <ThemeMenu />
          </div>
        )}
        <main className="mx-auto flex min-h-0 w-full max-w-[1600px] flex-1 flex-col overflow-hidden bg-[var(--kanban-board-bg)] px-2 pb-2 pt-3 sm:px-3 sm:pb-3 sm:pt-4 md:px-4 md:pb-4 md:pt-5">
          <div className="flex min-h-0 flex-1 flex-col overflow-hidden">{children}</div>
        </main>
      </div>

      {user && (
        <ProfileDrawer
          open={profileOpen}
          onClose={() => setProfileOpen(false)}
          user={user}
          onOpenNotifications={() => {
            setProfileOpen(false);
            setNotificationsOpen(true);
          }}
        />
      )}
      <NotificationsDrawer open={notificationsOpen} onClose={() => setNotificationsOpen(false)} />
      {user && (
        <>
          <PushPermissionPrompt />
          <NotificationToasts />
        </>
      )}

      <Dialog open={createOpen} onOpenChange={setCreateOpen} title="Новый проект">
        <form
          className="space-y-3"
          onSubmit={(e) => {
            e.preventDefault();
            if (projectName.trim()) createProject.mutate();
          }}
        >
          <div>
            <label className="label-text" htmlFor="np-name">
              Название
            </label>
            <Input id="np-name" value={projectName} onChange={(e) => setProjectName(e.target.value)} autoFocus />
          </div>
          <div>
            <label className="label-text" htmlFor="np-desc">
              Описание
            </label>
            <textarea
              id="np-desc"
              className="field min-h-[4rem] py-2"
              value={projectDesc}
              onChange={(e) => setProjectDesc(e.target.value)}
              placeholder="Необязательно"
            />
          </div>
          <Button type="submit" className="w-full" disabled={!projectName.trim() || createProject.isPending}>
            Создать
          </Button>
          {createProject.isError && (
            <p className="text-sm text-[var(--danger)]">{(createProject.error as Error).message}</p>
          )}
        </form>
      </Dialog>

      <Dialog
        open={!!membersProject}
        onOpenChange={(v) => !v && setMembersProjectId(null)}
        title={membersProject ? `Проект «${membersProject.name}»` : "Участники"}
        centerTitle
      >
        {membersProject && (
          <ProjectMembersDialog
            project={membersProject}
            userId={user?.id}
            onInvite={() => {
              const id = membersProject.id;
              setMembersProjectId(null);
              setInviteOpen(id);
              setInviteEmail("");
              setInviteNote("");
              setCopiedHint("");
            }}
            onRemove={(m) => removeMember(membersProject.id, m)}
            onDecideLeave={(reqId, approve) => void decideLeave(membersProject.id, reqId, approve)}
          />
        )}
      </Dialog>

      <Dialog
        open={!!renameProject}
        onOpenChange={(v) => !v && setRenameProjectId(null)}
        title="Название проекта"
        centerTitle
      >
        {renameProject && (
          <form
            className="space-y-3"
            onSubmit={(e) => {
              e.preventDefault();
              void saveRename();
            }}
          >
            <div>
              <label className="label-text" htmlFor="rename-project">
                Название
              </label>
              <Input
                id="rename-project"
                value={renameValue}
                onChange={(e) => setRenameValue(e.target.value)}
                autoFocus
              />
            </div>
            <Button type="submit" className="w-full" disabled={!renameValue.trim()}>
              Сохранить
            </Button>
          </form>
        )}
      </Dialog>

      <Dialog
        open={!!inviteOpen}
        onOpenChange={(v) => {
          if (!v) {
            setInviteOpen(null);
            setInviteEmail("");
            setInviteNote("");
            setCopiedHint("");
          }
        }}
        title="Пригласить участника"
      >
        <form
          className="space-y-3"
          onSubmit={(e) => {
            e.preventDefault();
            if (inviteOpen && inviteEmail.trim()) inviteMut.mutate(inviteOpen);
          }}
        >
          <div>
            <label className="label-text" htmlFor="inv-email">
              Email сотрудника
            </label>
            <Input
              id="inv-email"
              type="email"
              value={inviteEmail}
              onChange={(e) => setInviteEmail(e.target.value)}
              placeholder="colleague@example.com"
              autoFocus
            />
          </div>
          <Button type="submit" className="w-full" disabled={!inviteEmail.trim() || inviteMut.isPending}>
            Пригласить
          </Button>

          <div className="relative py-1 text-center text-[11px] font-medium uppercase tracking-wide text-muted">
            <span className="relative z-[1] bg-[var(--surface)] px-2">или</span>
            <span className="absolute inset-x-0 top-1/2 h-px bg-[var(--hairline)]" />
          </div>

          <Button
            type="button"
            variant="secondary"
            className="w-full"
            disabled={linkBusy}
            onClick={() => void ensureOpenInviteLink()}
          >
            {linkBusy ? "Готовим ссылку…" : "Скопировать ссылку для вступления"}
          </Button>
          <p className="text-xs text-muted">
            Отправьте ссылку в мессенджер — после входа или регистрации человек попадёт в проект.
          </p>

          {(copiedHint || inviteNote) && (
            <p className="text-xs text-muted">{copiedHint || inviteNote}</p>
          )}
          {inviteMut.isError && (
            <p className="text-sm text-[var(--danger)]">{(inviteMut.error as Error).message}</p>
          )}
          {(pendingInvites?.items?.length ?? 0) > 0 && (
            <div className="space-y-1.5 border-t border-hairline pt-3">
              <p className="text-xs font-semibold text-muted">Активные приглашения</p>
              {pendingInvites!.items.map((inv) => (
                <div key={inv.id} className="flex items-center justify-between gap-2 text-xs">
                  <span className="truncate">{inv.email || "Открытая ссылка"}</span>
                  <div className="flex shrink-0 items-center gap-2">
                    {inv.token && (
                      <button
                        type="button"
                        className="text-[var(--accent)]"
                        onClick={() => void copyInviteLink(inv.token!)}
                      >
                        Копировать
                      </button>
                    )}
                    <button
                      type="button"
                      className="text-[var(--danger)]"
                      onClick={async () => {
                        await api(`/api/v1/projects/${inviteOpen}/invites/${inv.id}`, { method: "DELETE" });
                        qc.invalidateQueries({ queryKey: ["project-invites", inviteOpen] });
                      }}
                    >
                      Отменить
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </form>
      </Dialog>
    </div>
  );
}

function MemberAvatarStack({ members }: { members: Project["members"] }) {
  if (!members.length) return null;
  const maxShown = 3;
  const shown = members.slice(0, maxShown);
  const extra = members.length - shown.length;
  const size = 28;
  const overlap = 10;
  const count = shown.length + (extra > 0 ? 1 : 0);
  const width = size + (count - 1) * (size - overlap);

  return (
    <span className="relative inline-block shrink-0" style={{ width, height: size }} aria-hidden>
      {shown.map((m, i) => (
        <span
          key={m.user_id}
          className="absolute top-0 overflow-hidden rounded-full"
          style={{ left: i * (size - overlap), width: size, height: size, zIndex: i + 1 }}
        >
          <UserAvatar name={m.name} avatarUrl={m.avatar_url} size={7} className="!h-full !w-full border-0" />
        </span>
      ))}
      {extra > 0 && (
        <span
          className="absolute top-0 flex items-center justify-center rounded-full bg-[#D5DBE2] text-[10px] font-bold text-[var(--graphite,#202938)] dark:bg-[#5A6570] dark:text-[var(--foreground)]"
          style={{
            left: shown.length * (size - overlap),
            width: size,
            height: size,
            zIndex: shown.length + 1,
          }}
        >
          +{extra}
        </span>
      )}
    </span>
  );
}

function ProjectMembersDialog({
  project,
  userId,
  onInvite,
  onRemove,
  onDecideLeave,
}: {
  project: Project;
  userId?: string;
  onInvite: () => void;
  onRemove: (m: Project["members"][number]) => void;
  onDecideLeave: (requestId: string, approve: boolean) => void;
}) {
  const [memberMenuId, setMemberMenuId] = useState<string | null>(null);
  const isOwner = project.members.some((m) => m.user_id === userId && m.role === "admin");
  const count = project.members.length;
  const { data: leaveData } = useQuery({
    queryKey: ["leave-requests", project.id],
    enabled: isOwner,
    queryFn: () => api<{ items: LeaveRequest[] }>(`/api/v1/projects/${project.id}/leave-requests`),
    staleTime: 15_000,
  });
  const pending = (leaveData?.items ?? []).filter((r) => r.status === "pending");

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between gap-2">
        <p className="text-[13px] font-semibold text-muted">
          {count === 1 ? "1 участник" : `${count} участников`}
        </p>
        {isOwner && (
          <button
            type="button"
            className="text-[14px] font-semibold text-[var(--accent)] hover:opacity-80"
            onClick={onInvite}
          >
            Добавить
          </button>
        )}
      </div>
      <ul className="-mx-1 space-y-0.5">
        {project.members.map((m) => {
          const canRemove = isOwner && m.user_id !== userId;
          const open = memberMenuId === m.user_id;
          return (
            <li
              key={m.user_id}
              className="relative flex items-center gap-2.5 rounded-[var(--radius)] px-1 py-1.5 text-[14px]"
            >
              <UserAvatar name={m.name} avatarUrl={m.avatar_url} size={7} />
              <span className="min-w-0 flex-1">
                <span className="block truncate font-semibold leading-tight">{m.name}</span>
                {m.role === "admin" && (
                  <span className="text-[12px] text-muted">Владелец</span>
                )}
              </span>
              {canRemove && (
                <button
                  type="button"
                  className="shrink-0 rounded p-1 text-muted hover:bg-[var(--surface-2)] hover:text-foreground"
                  aria-label="Ещё"
                  onClick={() => setMemberMenuId(open ? null : m.user_id)}
                >
                  <AppIcon name="more" size={16} />
                </button>
              )}
              {open && (
                <>
                  <button
                    type="button"
                    className="fixed inset-0 z-40 cursor-default"
                    aria-label="Закрыть"
                    onClick={() => setMemberMenuId(null)}
                  />
                  <div className="absolute right-0 top-9 z-50 w-48 rounded-[var(--radius)] border border-hairline bg-[var(--surface)] py-1 shadow-md">
                    <button
                      type="button"
                      className="block w-full px-3 py-2 text-left text-sm text-[var(--danger)] hover:bg-[var(--danger-soft)]"
                      onClick={() => {
                        setMemberMenuId(null);
                        onRemove(m);
                      }}
                    >
                      Удалить из проекта
                    </button>
                  </div>
                </>
              )}
            </li>
          );
        })}
      </ul>
      {isOwner && pending.length > 0 && (
        <div className="space-y-1.5 border-t border-hairline pt-3">
          <p className="text-[12px] font-semibold uppercase tracking-wide text-muted">
            Заявки на выход
          </p>
          {pending.map((req) => (
            <div key={req.id} className="flex items-center gap-2 text-[13px]">
              <UserAvatar name={req.user_name} avatarUrl={req.avatar_url} size={6} />
              <span className="min-w-0 flex-1 truncate">{req.user_name}</span>
              <button
                type="button"
                className="text-muted hover:text-foreground"
                onClick={() => onDecideLeave(req.id, false)}
              >
                Нет
              </button>
              <button
                type="button"
                className="font-medium text-[var(--accent)]"
                onClick={() => onDecideLeave(req.id, true)}
              >
                Удалить
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

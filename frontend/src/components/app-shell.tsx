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
import { NotificationsDrawer } from "@/components/notifications-drawer";
import { NotificationsMenu } from "@/components/notifications-menu";
import { ProfileDrawer } from "@/components/profile-drawer";
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
  const [expanded, setExpanded] = useState<Record<string, boolean>>({});
  const [profileOpen, setProfileOpen] = useState(false);
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const [createOpen, setCreateOpen] = useState(false);
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
  const { data: notifMeta } = useQuery({
    queryKey: ["notifications"],
    queryFn: () =>
      api<{ items: unknown[]; unread: number }>("/api/v1/notifications?page_size=1"),
    staleTime: 20_000,
    refetchInterval: 60_000,
  });

  const user = data?.user;
  const projects = useMemo(() => projectsData?.items ?? [], [projectsData?.items]);
  const myInvites = invitesData?.items ?? [];
  const unreadCount = notifMeta?.unread ?? 0;

  const currentProjectId = useMemo(() => {
    const m = pathname.match(/^\/app\/projects\/([^/?#]+)/);
    return m?.[1] ?? null;
  }, [pathname]);

  useEffect(() => {
    if (currentProjectId) setLastProjectId(currentProjectId);
  }, [currentProjectId]);

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

  function toggleExpand(id: string, e: React.MouseEvent) {
    e.preventDefault();
    e.stopPropagation();
    setExpanded((prev) => ({ ...prev, [id]: !prev[id] }));
  }

  function openProject(id: string) {
    setLastProjectId(id);
    setMobileOpen(false);
    router.push(`/app/projects/${id}`);
  }

  async function removeMember(projectId: string, member: Project["members"][number]) {
    if (!confirm(`Убрать ${member.name} из проекта?`)) return;
    await api(`/api/v1/projects/${projectId}/members/${member.user_id}`, { method: "DELETE" });
    qc.invalidateQueries({ queryKey: ["projects"] });
    qc.invalidateQueries({ queryKey: ["leave-requests", projectId] });
  }

  async function requestLeave(projectId: string, projectName: string) {
    if (!confirm(`Отправить заявку на выход из «${projectName}»?`)) return;
    await api(`/api/v1/projects/${projectId}/leave-requests`, { method: "POST" });
    qc.invalidateQueries({ queryKey: ["notifications"] });
    alert("Заявка отправлена владельцу проекта");
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

  const Sidebar = (
    <aside className="flex h-full w-[15.5rem] shrink-0 flex-col border-r border-hairline bg-[var(--sidebar,var(--surface))]">
      <div className="flex shrink-0 items-center justify-between gap-2 px-3.5 py-4">
        <Link href="/app/projects" className="inline-flex min-w-0" aria-label="Takt">
          <BrandLogo className="h-6" />
        </Link>
        <div className="flex items-center gap-0.5">
          <NotificationsMenu onOpen={() => setNotificationsOpen(true)} />
          <ThemeMenu />
        </div>
      </div>

      <div className="shrink-0 px-2 pb-2">
        <button
          type="button"
          onClick={() => {
            setNotificationsOpen(true);
            setMobileOpen(false);
          }}
          className={cn(
            "flex w-full items-center gap-2 rounded-[var(--radius)] px-2.5 py-2 text-left text-[13px]",
            notificationsOpen
              ? "bg-[var(--surface-2)] font-semibold text-foreground"
              : "text-[var(--muted-fg)] hover:bg-[var(--surface-2)] hover:text-foreground"
          )}
        >
          <AppIcon name="notifications" size={16} className="shrink-0" />
          <span className="min-w-0 flex-1">Уведомления</span>
          {unreadCount > 0 && (
            <span className="rounded-full bg-[var(--accent)] px-1.5 py-0.5 text-[10px] font-semibold text-white">
              {unreadCount > 99 ? "99+" : unreadCount}
            </span>
          )}
        </button>
      </div>

      {myInvites.length > 0 && (
        <div className="mx-3 mb-3 space-y-2 rounded-[var(--radius)] border border-hairline bg-[var(--surface-2)] p-2.5">
          <p className="text-[11px] font-semibold uppercase tracking-wide text-muted">Приглашения</p>
          {myInvites.map((inv) => (
            <div key={inv.id} className="space-y-1.5">
              <p className="text-xs leading-snug">
                <span className="font-medium">{inv.project_name}</span>
                {inv.invited_by_name ? ` · ${inv.invited_by_name}` : ""}
              </p>
              <div className="flex gap-1">
                <Button
                  size="sm"
                  className="h-7 px-2 text-xs"
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
                  className="h-7 px-2 text-xs"
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

      <div className="shrink-0 px-3 pb-1">
        <p className="section-label px-1.5">Мои проекты</p>
      </div>

      <nav className="min-h-0 flex-1 space-y-0.5 overflow-y-auto overscroll-contain px-2 pb-3" aria-label="Проекты">
        {projects.map((p) => {
          const active = p.id === currentProjectId;
          const open = !!expanded[p.id];
          const isOwner = p.members.some((m) => m.user_id === user?.id && m.role === "admin");
          const adminCount = p.members.filter((m) => m.role === "admin").length;
          return (
            <div key={p.id} className="rounded-[var(--radius)]">
              <div
                className={cn(
                  "flex items-center gap-0.5 rounded-[var(--radius)] px-1 py-0.5",
                  active && "bg-[var(--surface-2)]"
                )}
              >
                <button
                  type="button"
                  className="flex h-8 w-7 shrink-0 items-center justify-center rounded text-muted hover:text-foreground"
                  aria-label={open ? "Свернуть участников" : "Показать участников"}
                  onClick={(e) => toggleExpand(p.id, e)}
                >
                  {open ? <AppIcon name="chevron-down" size={16} /> : <AppIcon name="chevron-right" size={16} />}
                </button>
                <button
                  type="button"
                  className={cn(
                    "min-w-0 flex-1 truncate py-1.5 pr-2 text-left text-[13px]",
                    active ? "font-semibold text-foreground" : "text-[var(--muted-fg)] hover:text-foreground"
                  )}
                  onClick={() => openProject(p.id)}
                >
                  {p.name}
                </button>
              </div>
              {open && (
                <ProjectMembersPanel
                  project={p}
                  userId={user?.id}
                  isOwner={isOwner}
                  adminCount={adminCount}
                  onInvite={() => {
                    setInviteOpen(p.id);
                    setInviteEmail("");
                    setInviteNote("");
                    setCopiedHint("");
                  }}
                  onRemove={(m) => removeMember(p.id, m)}
                  onLeave={() => requestLeave(p.id, p.name)}
                  onDecideLeave={(reqId, approve) => decideLeave(p.id, reqId, approve)}
                />
              )}
            </div>
          );
        })}
        {!projects.length && <p className="px-2.5 py-2 text-xs text-muted">Пока нет проектов</p>}
      </nav>

      <div className="shrink-0 border-t border-hairline p-2.5">
        <Button
          variant="secondary"
          className="mb-2 w-full justify-start"
          size="sm"
          onClick={() => setCreateOpen(true)}
        >
          <AppIcon name="add" size={16} /> Создать проект
        </Button>
        {user && hasPlatformAccess(user.platform_role) && (
          <Link
            href="/admin"
            className="mb-2 flex w-full items-center gap-2 rounded-[var(--radius)] px-2 py-1.5 text-[13px] font-medium text-[var(--accent)] hover:bg-[var(--accent-soft)]"
          >
            <AppIcon name="settings" size={16} />
            Админка платформы
          </Link>
        )}
        {user && (
          <button
            type="button"
            className="flex w-full items-center gap-2 rounded-[var(--radius)] px-1.5 py-1.5 text-left hover:bg-[var(--surface-2)]"
            onClick={() => setProfileOpen(true)}
          >
            <UserAvatar name={user.name} avatarUrl={user.avatar_url} size={8} />
            <span className="min-w-0 flex-1 truncate text-[13px] font-medium">{user.name}</span>
          </button>
        )}
      </div>
    </aside>
  );

  return (
    <div className="flex h-dvh overflow-hidden">
      <div className="sticky top-0 hidden h-dvh shrink-0 self-start lg:block">{Sidebar}</div>
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
        <main className="mx-auto flex min-h-0 w-full max-w-[1600px] flex-1 flex-col overflow-hidden bg-[var(--kanban-board-bg)] p-3 md:p-4">
          <div className="flex min-h-0 flex-1 flex-col overflow-y-auto overscroll-contain">{children}</div>
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

function ProjectMembersPanel({
  project,
  userId,
  isOwner,
  adminCount,
  onInvite,
  onRemove,
  onLeave,
  onDecideLeave,
}: {
  project: Project;
  userId?: string;
  isOwner: boolean;
  adminCount: number;
  onInvite: () => void;
  onRemove: (m: Project["members"][number]) => void;
  onLeave: () => void;
  onDecideLeave: (requestId: string, approve: boolean) => void;
}) {
  const { data: leaveData } = useQuery({
    queryKey: ["leave-requests", project.id],
    enabled: isOwner,
    queryFn: () => api<{ items: LeaveRequest[] }>(`/api/v1/projects/${project.id}/leave-requests`),
    staleTime: 15_000,
  });
  const pending = (leaveData?.items ?? []).filter((r) => r.status === "pending");

  return (
    <ul className="mb-1 ml-7 space-y-0.5 border-l border-hairline pl-2">
      {project.members.map((m) => {
        const isSelf = m.user_id === userId;
        const canRemove = isOwner && !isSelf;
        const canLeave = !!isSelf && !(m.role === "admin" && adminCount <= 1);
        return (
          <li key={m.user_id} className="flex items-center gap-1.5 py-1 text-xs text-muted">
            <UserAvatar name={m.name} avatarUrl={m.avatar_url} size={5} />
            <span className="min-w-0 flex-1 truncate">{m.name}</span>
            {m.role === "admin" && <span className="shrink-0 text-[10px]">владелец</span>}
            {canRemove && (
              <button
                type="button"
                className="shrink-0 rounded p-0.5 text-muted hover:text-[var(--danger)]"
                title="Удалить из проекта"
                onClick={() => onRemove(m)}
              >
                <AppIcon name="delete" size={16} />
              </button>
            )}
            {canLeave && (
              <button
                type="button"
                className="shrink-0 text-[11px] font-medium text-[var(--accent)]"
                onClick={onLeave}
              >
                Выйти
              </button>
            )}
          </li>
        );
      })}
      {isOwner && pending.length > 0 && (
        <li className="space-y-1 pt-1">
          <p className="text-[10px] font-semibold uppercase tracking-wide text-muted">Заявки на выход</p>
          {pending.map((req) => (
            <div key={req.id} className="flex items-center gap-1.5 text-xs">
              <UserAvatar name={req.user_name} avatarUrl={req.avatar_url} size={5} />
              <span className="min-w-0 flex-1 truncate">{req.user_name}</span>
              <button
                type="button"
                className="text-[11px] text-muted hover:text-foreground"
                onClick={() => onDecideLeave(req.id, false)}
              >
                Нет
              </button>
              <button
                type="button"
                className="text-[11px] font-medium text-[var(--accent)]"
                onClick={() => onDecideLeave(req.id, true)}
              >
                Удалить
              </button>
            </div>
          ))}
        </li>
      )}
      {isOwner && (
        <li>
          <button type="button" className="py-1 text-xs font-medium text-[var(--accent)]" onClick={onInvite}>
            + Добавить участника
          </button>
        </li>
      )}
    </ul>
  );
}

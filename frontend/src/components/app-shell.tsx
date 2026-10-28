"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import {
  LayoutDashboard,
  FolderKanban,
  ListTodo,
  UserRound,
  BarChart3,
  Users,
  LogOut,
  Bell,
  Menu,
  X,
  Search,
  Plus,
} from "lucide-react";
import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { api } from "@/lib/api";
import type { NotificationItem, Project, User as AppUser } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { UserAvatar } from "@/components/user-avatar";
import { ThemeMenu } from "@/components/ui/theme-menu";
import { BrandWordmark } from "@/components/brand-mark";
import { cn } from "@/lib/utils";

const nav = [
  { href: "/home", label: "Обзор", hint: "Что важно сегодня", icon: LayoutDashboard },
  { href: "/my", label: "Мои задачи", hint: "Поручения вам", icon: UserRound },
  { href: "/projects", label: "Проекты", hint: "Доски по проектам", icon: FolderKanban },
  { href: "/list", label: "Список", hint: "Все задачи таблицей", icon: ListTodo },
  { href: "/report", label: "Отчёты", hint: "Сводка по команде", icon: BarChart3 },
];

const mobileNav = [
  { href: "/home", label: "Обзор", icon: LayoutDashboard },
  { href: "/my", label: "Мои", icon: UserRound },
  { href: "/projects", label: "Проекты", icon: FolderKanban },
  { href: "/list", label: "Список", icon: ListTodo },
];

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [mobileOpen, setMobileOpen] = useState(false);
  const [search, setSearch] = useState("");
  const { data } = useQuery({
    queryKey: ["me"],
    queryFn: () => api<{ user: AppUser }>("/api/v1/auth/me"),
    staleTime: 60_000,
  });
  const { data: projectsData } = useQuery({
    queryKey: ["projects"],
    queryFn: () => api<{ items: Project[] }>("/api/v1/projects"),
    staleTime: 30_000,
  });
  const { data: notifData } = useQuery({
    queryKey: ["notifications"],
    queryFn: () => api<{ items: NotificationItem[]; unread: number }>("/api/v1/notifications?page_size=10"),
    refetchInterval: 60_000,
    staleTime: 20_000,
  });
  const user = data?.user;
  const projects = projectsData?.items ?? [];
  const unread = notifData?.unread ?? 0;
  const defaultProject = projects.find((p) => p.is_default) ?? projects[0];

  async function logout() {
    await api("/api/v1/auth/logout", { method: "POST" });
    router.push("/login");
  }

  function submitSearch(e: React.FormEvent) {
    e.preventDefault();
    const q = search.trim();
    if (!q) return;
    router.push(`/list?search=${encodeURIComponent(q)}`);
    setMobileOpen(false);
  }

  function goCreate() {
    const target = defaultProject ?? projects[0];
    if (target) router.push(`/projects/${target.id}?create=1`);
    else router.push("/projects?create=1");
    setMobileOpen(false);
  }

  const Sidebar = (
    <aside className="flex h-full w-[15.5rem] flex-col border-r border-hairline bg-[var(--surface)]">
      <div className="px-3.5 py-4">
        <BrandWordmark />
      </div>

      <div className="px-3 pb-3">
        <Button className="w-full justify-center" size="default" onClick={goCreate} aria-label="Создать задачу">
          <Plus className="h-4 w-4" />
          Создать задачу
        </Button>
      </div>

      <nav className="flex-1 space-y-0.5 overflow-y-auto px-2 pb-3" aria-label="Основное меню">
        {nav.map(({ href, label, hint, icon: Icon }) => {
          const active = pathname === href || pathname.startsWith(href + "/");
          return (
            <Link
              key={href}
              href={href}
              onClick={() => setMobileOpen(false)}
              data-active={active}
              className="nav-link"
              title={hint}
            >
              <Icon className="h-4 w-4 shrink-0 opacity-80" aria-hidden />
              <span className="min-w-0 truncate">{label}</span>
            </Link>
          );
        })}
        {user?.role === "admin" && (
          <Link
            href="/admin"
            onClick={() => setMobileOpen(false)}
            data-active={pathname.startsWith("/admin")}
            className="nav-link"
            title="Пользователи и настройки"
          >
            <Users className="h-4 w-4 shrink-0 opacity-80" aria-hidden />
            <span>Пользователи</span>
          </Link>
        )}

        <div className="pt-4">
          <div className="section-label px-2.5 pb-1.5">Проекты</div>
          <div className="max-h-52 space-y-0.5 overflow-y-auto">
            {projects.map((p) => (
              <Link
                key={p.id}
                href={`/projects/${p.id}`}
                onClick={() => setMobileOpen(false)}
                className={cn(
                  "flex items-center gap-2 rounded-[var(--radius)] px-2.5 py-1.5 text-[13px]",
                  pathname.includes(p.id)
                    ? "bg-[var(--surface-2)] font-semibold text-foreground"
                    : "text-[var(--muted-fg)] hover:bg-[var(--surface-2)]"
                )}
              >
                <span className="h-2 w-2 shrink-0 rounded-full" style={{ background: p.color }} />
                <span className="truncate">{p.name}</span>
              </Link>
            ))}
            {!projects.length && <p className="px-2.5 text-xs text-muted">Пока нет проектов</p>}
          </div>
        </div>
      </nav>

      <div className="border-t border-hairline p-2.5">
        {user && (
          <div className="flex items-center gap-1.5">
            <Link href="/profile" onClick={() => setMobileOpen(false)} className="min-w-0 flex-1">
              <div className="flex items-center gap-2 rounded-[var(--radius)] p-1 hover:bg-[var(--surface-2)]">
                <UserAvatar name={user.name} avatarUrl={user.avatar_url} size={8} />
                <div className="min-w-0">
                  <div className="truncate text-[13px] font-semibold">{user.name}</div>
                  <div className="truncate text-[11px] text-muted">{user.email}</div>
                </div>
              </div>
            </Link>
            <Button variant="ghost" size="icon" aria-label="Выйти" onClick={logout}>
              <LogOut className="h-4 w-4" />
            </Button>
          </div>
        )}
      </div>
    </aside>
  );

  return (
    <div className="min-h-screen bg-background text-foreground">
      <div className="flex min-h-screen">
        <div className="hidden lg:block">{Sidebar}</div>
        {mobileOpen && (
          <div className="fixed inset-0 z-50 flex lg:hidden">
            <div className="absolute inset-0 bg-black/35" onClick={() => setMobileOpen(false)} aria-hidden />
            <div className="relative z-10 h-full border-r border-hairline">{Sidebar}</div>
          </div>
        )}
        <div className="flex min-w-0 flex-1 flex-col">
          <header className="sticky top-0 z-30 flex h-12 items-center gap-2 border-b border-hairline bg-[var(--surface)]/90 px-3 backdrop-blur md:gap-2.5 md:px-4">
            <Button
              variant="ghost"
              size="icon"
              className="lg:hidden"
              aria-label={mobileOpen ? "Закрыть меню" : "Открыть меню"}
              onClick={() => setMobileOpen((v) => !v)}
            >
              {mobileOpen ? <X className="h-4 w-4" /> : <Menu className="h-4 w-4" />}
            </Button>
            <form onSubmit={submitSearch} className="relative min-w-0 flex-1">
              <Search className="pointer-events-none absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted" />
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Найти задачу…"
                aria-label="Поиск задач"
                className="field h-9 py-0 pl-8 pr-2"
              />
            </form>
            <Button
              variant="secondary"
              size="icon"
              className="hidden sm:inline-flex lg:hidden"
              onClick={goCreate}
              aria-label="Создать задачу"
            >
              <Plus className="h-4 w-4" />
            </Button>
            <Link
              href="/inbox"
              className="relative inline-flex h-9 w-9 items-center justify-center rounded-[var(--radius)] text-muted hover:bg-[var(--surface-2)] hover:text-foreground"
              aria-label={unread ? `Уведомления, непрочитанных: ${unread}` : "Уведомления"}
            >
              <Bell className="h-4 w-4" />
              {unread > 0 && (
                <span className="absolute right-1 top-1 flex h-3.5 min-w-3.5 items-center justify-center rounded-full bg-[var(--accent)] px-0.5 text-[9px] font-bold text-[var(--accent-fg)]">
                  {unread > 9 ? "9+" : unread}
                </span>
              )}
            </Link>
            <ThemeMenu />
            <Link href="/profile" className="hidden sm:block" aria-label="Профиль">
              {user && <UserAvatar name={user.name} avatarUrl={user.avatar_url} size={8} />}
            </Link>
          </header>

          <main className="mx-auto w-full max-w-[1440px] flex-1 p-3 pb-[4.75rem] md:p-5 lg:pb-5">{children}</main>

          <nav
            className="fixed inset-x-0 bottom-0 z-40 border-t border-hairline bg-[var(--surface)]/95 backdrop-blur safe-pb lg:hidden"
            aria-label="Мобильная навигация"
          >
            <div className="mx-auto grid max-w-lg grid-cols-5 gap-0.5 px-1 pt-0.5">
              {mobileNav.map(({ href, label, icon: Icon }) => {
                const active = pathname === href || pathname.startsWith(href + "/");
                return (
                  <Link
                    key={href}
                    href={href}
                    className={cn(
                      "flex min-h-[48px] flex-col items-center justify-center gap-0.5 rounded-[var(--radius)] text-[10px] font-semibold",
                      active ? "text-[var(--accent)]" : "text-muted"
                    )}
                  >
                    <Icon className="h-[18px] w-[18px]" aria-hidden />
                    {label}
                  </Link>
                );
              })}
              <button
                type="button"
                onClick={goCreate}
                aria-label="Создать задачу"
                className="flex min-h-[48px] flex-col items-center justify-center gap-0.5 rounded-[var(--radius)] text-[10px] font-semibold text-[var(--accent)]"
              >
                <span
                  className="flex h-7 w-7 items-center justify-center rounded-full bg-[var(--accent)] text-[var(--accent-fg)]"
                  aria-hidden
                >
                  <Plus className="h-4 w-4" />
                </span>
                Создать
              </button>
            </div>
          </nav>
        </div>
      </div>
    </div>
  );
}

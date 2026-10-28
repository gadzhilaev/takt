"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { LayoutGrid, List, User, BarChart3, Shield, LogOut, Sun, Moon } from "lucide-react";
import { useTheme } from "next-themes";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { User as AppUser } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { UserAvatar } from "@/components/user-avatar";
import { cn } from "@/lib/utils";

const nav = [
  { href: "/board", label: "Доска", icon: LayoutGrid },
  { href: "/list", label: "Список", icon: List },
  { href: "/my", label: "Мои задачи", icon: User },
  { href: "/report", label: "Отчёт", icon: BarChart3 },
  { href: "/profile", label: "Профиль", icon: User },
];

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const { theme, setTheme } = useTheme();
  const { data } = useQuery({
    queryKey: ["me"],
    queryFn: () => api<{ user: AppUser }>("/api/v1/auth/me"),
  });
  const user = data?.user;

  async function logout() {
    await api("/api/v1/auth/logout", { method: "POST" });
    router.push("/login");
  }

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 dark:bg-slate-950 dark:text-slate-50">
      <header className="sticky top-0 z-40 border-b border-slate-200/80 bg-white/80 backdrop-blur dark:border-slate-800 dark:bg-slate-950/80">
        <div className="mx-auto flex max-w-[1600px] items-center gap-4 px-4 py-3">
          <Link href="/board" className="text-lg font-semibold text-indigo-600">
            Трекер задач
          </Link>
          <nav className="hidden flex-1 items-center gap-1 md:flex">
            {nav.map(({ href, label, icon: Icon }) => (
              <Link
                key={href}
                href={href}
                className={cn(
                  "inline-flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium transition-colors",
                  pathname.startsWith(href)
                    ? "bg-indigo-50 text-indigo-700 dark:bg-indigo-950/50 dark:text-indigo-200"
                    : "text-slate-600 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-slate-800"
                )}
              >
                <Icon className="h-4 w-4" />
                {label}
              </Link>
            ))}
            {user?.role === "admin" && (
              <Link
                href="/admin"
                className={cn(
                  "inline-flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium",
                  pathname.startsWith("/admin")
                    ? "bg-indigo-50 text-indigo-700"
                    : "text-slate-600 hover:bg-slate-100"
                )}
              >
                <Shield className="h-4 w-4" />
                Админка
              </Link>
            )}
          </nav>
          <div className="ml-auto flex items-center gap-2">
            <Button
              variant="ghost"
              size="icon"
              aria-label="Тема"
              onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
            >
              {theme === "dark" ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
            </Button>
            {user && (
              <>
                <UserAvatar name={user.name} avatarUrl={user.avatar_url} size={9} />
                <Button variant="ghost" size="icon" aria-label="Выйти" onClick={logout}>
                  <LogOut className="h-4 w-4" />
                </Button>
              </>
            )}
          </div>
        </div>
        <nav className="flex gap-1 overflow-x-auto border-t border-slate-100 px-2 py-2 md:hidden dark:border-slate-800">
          {[...nav, ...(user?.role === "admin" ? [{ href: "/admin", label: "Админка", icon: Shield }] : [])].map(
            ({ href, label, icon: Icon }) => (
              <Link
                key={href}
                href={href}
                className={cn(
                  "shrink-0 rounded-lg px-3 py-2 text-xs font-medium",
                  pathname.startsWith(href) ? "bg-indigo-600 text-white" : "bg-slate-100"
                )}
              >
                <Icon className="mx-auto h-4 w-4" />
                {label}
              </Link>
            )
          )}
        </nav>
      </header>
      <main className="mx-auto max-w-[1600px] p-4">{children}</main>
    </div>
  );
}

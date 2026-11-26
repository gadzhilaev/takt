"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useRef } from "react";
import { useTheme } from "next-themes";
import { useQuery } from "@tanstack/react-query";
import {
  ArrowRight,
  Activity,
  FolderKanban,
  LayoutDashboard,
  Settings2,
  ShieldAlert,
  UsersRound,
  type LucideIcon,
} from "lucide-react";
import { api } from "@/lib/api";
import { BrandLogo } from "@/components/brand-mark";
import { cn } from "@/lib/utils";
import { platformRoleLabel } from "@/lib/types";

const NAV_BASE: { href: string; label: string; icon: LucideIcon; exact?: boolean }[] = [
  { href: "/admin", label: "Обзор", icon: LayoutDashboard, exact: true },
  { href: "/admin/users", label: "Пользователи", icon: UsersRound },
  { href: "/admin/projects", label: "Проекты", icon: FolderKanban },
  { href: "/admin/moderation", label: "Модерация", icon: ShieldAlert },
  { href: "/admin/system", label: "Система", icon: Activity },
];

type PlatformMe = { platform_role: string; name: string; email: string };

function useForceLightTheme() {
  const { theme, setTheme } = useTheme();
  const prevTheme = useRef<string | undefined>();
  useEffect(() => {
    prevTheme.current = theme;
    setTheme("light");
    return () => {
      if (prevTheme.current && prevTheme.current !== "light") setTheme(prevTheme.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [setTheme]);
}

export default function PlatformAdminLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  useForceLightTheme();
  const allowedMe = useRef<PlatformMe | null>(null);
  const me = useQuery({
    queryKey: ["platform-me"],
    queryFn: () => api<PlatformMe>("/api/v1/platform/me"),
    retry: false,
  });

  if (me.data) allowedMe.current = me.data;
  const user = me.data ?? allowedMe.current;

  useEffect(() => {
    if (me.isError && !allowedMe.current) router.replace("/login?next=/admin");
  }, [me.isError, router]);

  if (!user) {
    return (
      <div className="platform-admin flex min-h-screen items-center justify-center px-4 text-sm text-muted">
        {me.isError ? "Переход ко входу…" : "Проверка доступа…"}
      </div>
    );
  }

  const nav =
    user.platform_role === "super_admin"
      ? [...NAV_BASE, { href: "/admin/settings", label: "Настройки", icon: Settings2 }]
      : NAV_BASE;
  const activeItem = nav.find((item) =>
    item.exact ? pathname === item.href : pathname.startsWith(item.href)
  );

  return (
    <div className="platform-admin min-h-screen text-[#202938]">
      <aside className="fixed inset-y-0 left-0 z-40 flex w-[4.25rem] flex-col border-r border-[#dce2e7] bg-white sm:w-60">
        <div className="border-b border-[#edf0f2] p-3 sm:px-5 sm:py-4">
          <Link href="/admin" aria-label="Takt — обзор админки" className="flex h-9 items-center justify-center sm:justify-start">
            <BrandLogo variant="light" className="hidden h-7 w-auto max-w-[8rem] sm:block" />
            <span className="text-base font-bold text-[#315f72] sm:hidden">T</span>
          </Link>
          <p className="mt-2 hidden text-[11px] font-medium text-[#667485] sm:block">Управление платформой</p>
        </div>
        <nav aria-label="Разделы админки" className="flex-1 space-y-1 overflow-y-auto p-2 sm:p-3">
            {nav.map((item) => {
              const active = item.exact ? pathname === item.href : pathname.startsWith(item.href);
              const Icon = item.icon;
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  aria-current={active ? "page" : undefined}
                  className={cn(
                    "flex h-10 items-center justify-center gap-2 rounded-[var(--radius)] px-2 text-[13px] font-medium transition-colors sm:justify-start sm:px-3",
                    active
                      ? "bg-[#e8eef1] text-[#315f72]"
                      : "text-[#667485] hover:bg-[#f4f6f8] hover:text-[#202938]"
                  )}
                >
                  <Icon size={16} strokeWidth={1.8} aria-hidden />
                  <span className="hidden sm:inline">{item.label}</span>
                </Link>
              );
            })}
        </nav>
        <div className="border-t border-[#edf0f2] p-2 sm:p-3">
          <p className="hidden truncate px-2 text-[12px] font-semibold text-[#202938] sm:block">{user.name}</p>
          <p className="hidden truncate px-2 pb-2 text-[11px] text-[#667485] sm:block">{platformRoleLabel(user.platform_role)}</p>
          <Link href="/app/projects" title="К проектам" className="flex h-10 items-center justify-center gap-2 rounded-[var(--radius)] border border-[#dce2e7] px-2 text-[12px] font-semibold text-[#315f72] transition-colors hover:bg-[#f1f3f5] sm:justify-start sm:px-3">
            <ArrowRight size={16} aria-hidden />
            <span className="hidden sm:inline">К проектам</span>
          </Link>
        </div>
      </aside>
      <main className="ml-[4.25rem] min-h-screen px-4 py-6 sm:ml-60 sm:px-6 sm:py-8">
        {activeItem && !activeItem.exact ? (
          <p className="mb-3 text-[11px] font-semibold uppercase tracking-[0.12em] text-[#81909d]">
            Takt <span className="px-1.5 text-[#b7c0c8]">/</span> {activeItem.label}
          </p>
        ) : null}
        {children}
      </main>
    </div>
  );
}

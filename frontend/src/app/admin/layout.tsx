"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useRef } from "react";
import { useTheme } from "next-themes";
import { useQuery } from "@tanstack/react-query";
import {
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
      <header className="sticky top-0 z-40 border-b border-[#dce2e7] bg-white/95 backdrop-blur">
        <div className="mx-auto flex h-[3.75rem] max-w-[84rem] items-center justify-between gap-4 px-4 sm:px-6">
          <div className="flex min-w-0 items-center gap-3">
            <Link href="/admin" aria-label="Takt — обзор админки" className="shrink-0">
              <BrandLogo variant="light" className="h-7 w-auto max-w-[8rem]" />
            </Link>
            <span className="hidden h-6 w-px bg-[#dce2e7] sm:block" aria-hidden />
            <span className="truncate text-[13px] font-medium text-[#667485]">Управление платформой</span>
          </div>
          <div className="flex shrink-0 items-center gap-3">
            <div className="hidden text-right sm:block">
              <p className="max-w-48 truncate text-[12px] font-semibold leading-4 text-[#202938]">
                {user.name}
              </p>
              <p className="text-[11px] leading-4 text-[#667485]">
                {platformRoleLabel(user.platform_role)}
              </p>
            </div>
            <Link
              href="/app/projects"
              className="inline-flex h-9 items-center rounded-[var(--radius)] border border-[#dce2e7] px-3 text-[12px] font-semibold text-[#315f72] transition-colors hover:bg-[#f1f3f5]"
            >
              К проектам
            </Link>
          </div>
        </div>
        <div className="border-t border-[#edf0f2]">
          <nav
            aria-label="Разделы админки"
            className="mx-auto flex max-w-[84rem] gap-1 overflow-x-auto px-3 py-2 sm:px-5"
          >
            {nav.map((item) => {
              const active = item.exact ? pathname === item.href : pathname.startsWith(item.href);
              const Icon = item.icon;
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  aria-current={active ? "page" : undefined}
                  className={cn(
                    "inline-flex h-9 shrink-0 items-center gap-2 rounded-[var(--radius)] px-3 text-[13px] font-medium transition-colors",
                    active
                      ? "bg-[#e8eef1] text-[#315f72]"
                      : "text-[#667485] hover:bg-[#f4f6f8] hover:text-[#202938]"
                  )}
                >
                  <Icon size={16} strokeWidth={1.8} aria-hidden />
                  {item.label}
                </Link>
              );
            })}
          </nav>
        </div>
      </header>
      <main className="mx-auto min-h-[calc(100vh-7rem)] max-w-[84rem] px-4 py-6 sm:px-6 sm:py-8">
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

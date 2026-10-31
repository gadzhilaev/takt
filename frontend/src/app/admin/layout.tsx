"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useRef } from "react";
import { useTheme } from "next-themes";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { BrandLogo } from "@/components/brand-mark";
import { cn } from "@/lib/utils";
import { platformRoleLabel } from "@/lib/types";

const NAV = [
  { href: "/admin", label: "Обзор", exact: true },
  { href: "/admin/users", label: "Пользователи" },
  { href: "/admin/projects", label: "Проекты" },
  { href: "/admin/moderation", label: "Модерация" },
  { href: "/admin/system", label: "Система" },
  { href: "/admin/settings", label: "Настройки" },
];

type PlatformMe = { platform_role: string; name: string; email: string };

/** Admin chrome is light-only; hold next-themes on light while mounted. */
function useForceLightTheme() {
  const { theme, setTheme } = useTheme();
  const prevTheme = useRef<string | undefined>();
  useEffect(() => {
    prevTheme.current = theme;
    setTheme("light");
    return () => {
      if (prevTheme.current && prevTheme.current !== "light") {
        setTheme(prevTheme.current);
      }
    };
    // Intentionally once on mount/unmount — ignore theme churn while in admin.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [setTheme]);
}

export default function PlatformAdminLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  useForceLightTheme();
  /** Keep shell mounted after first success so HMR/refetch doesn't wipe form state. */
  const allowedMe = useRef<PlatformMe | null>(null);
  const me = useQuery({
    queryKey: ["platform-me"],
    queryFn: () => api<PlatformMe>("/api/v1/platform/me"),
    retry: false,
  });

  if (me.data) allowedMe.current = me.data;
  const user = me.data ?? allowedMe.current;

  if (me.isError && !user) {
    return (
      <div className="platform-admin flex min-h-screen flex-col items-center justify-center gap-3 px-4 text-center">
        <p className="text-sm text-[#5a6573]">Нет доступа к панели платформы Takt.</p>
        <p className="max-w-sm text-[13px] text-[#5a6573]">
          Войдите обычным аккаунтом на /login. Ссылка на админку появится в профиле, если у вас есть
          роль платформы.
        </p>
        <button
          type="button"
          className="text-sm font-semibold text-[#315f72]"
          onClick={() => router.push("/app/projects")}
        >
          В рабочее пространство
        </button>
        <button
          type="button"
          className="text-sm text-[#5a6573] underline-offset-2 hover:underline"
          onClick={() => router.push("/login?next=/admin")}
        >
          Войти
        </button>
      </div>
    );
  }

  if (!user) {
    return (
      <div className="platform-admin flex min-h-screen items-center justify-center text-sm text-[#5a6573]">
        Проверка доступа…
      </div>
    );
  }

  return (
    <div className="platform-admin min-h-screen text-[#202938]">
      <header className="border-b border-[#dce2e7] bg-white">
        <div className="mx-auto flex h-14 max-w-7xl items-center justify-between gap-4 px-4">
          <div className="flex items-center gap-3">
            <Link href="/admin" aria-label="Takt Admin">
              <BrandLogo variant="light" className="h-7 w-auto max-w-[8rem]" />
            </Link>
            <span className="rounded bg-[#202938] px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-white">
              Admin
            </span>
          </div>
          <div className="flex items-center gap-3 text-[13px] text-[#5a6573]">
            <span className="hidden sm:inline">
              {user.name} · {platformRoleLabel(user.platform_role)}
            </span>
            <Link href="/app/projects" className="font-medium text-[#315f72]">
              К доскам
            </Link>
          </div>
        </div>
      </header>
      <div className="mx-auto flex max-w-7xl gap-6 px-4 py-6">
        <nav className="hidden w-48 shrink-0 md:block" aria-label="Разделы админки">
          <ul className="space-y-1">
            {NAV.map((item) => {
              const active = item.exact ? pathname === item.href : pathname.startsWith(item.href);
              return (
                <li key={item.href}>
                  <Link
                    href={item.href}
                    className={cn(
                      "block rounded-[var(--radius)] px-3 py-2 text-[13px] font-medium",
                      active
                        ? "bg-[#e8eef1] text-[#315f72]"
                        : "text-[#5a6573] hover:bg-white hover:text-[#202938]"
                    )}
                  >
                    {item.label}
                  </Link>
                </li>
              );
            })}
          </ul>
        </nav>
        <main className="min-w-0 flex-1 text-[#202938]">{children}</main>
      </div>
    </div>
  );
}

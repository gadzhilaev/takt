"use client";

import { useEffect, useState } from "react";
import { usePathname } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { AppIcon } from "@/components/ui/app-icon";
import { Button } from "@/components/ui/button";
import { api } from "@/lib/api";
import type { Project, User } from "@/lib/types";

/** app-shell слушает это событие и открывает диалог настроек проекта (там же — ритм). */
export const OPEN_PROJECT_SETTINGS_EVENT = "takt:open-project-settings";

const dismissKey = (projectId: string) => `takt:rhythmCardDismissed:${projectId}`;

/**
 * Подсказка администратору проекта: ежедневный чек-ин ещё выключен.
 * Показывается только над доской проекта (`/app/projects/{id}`), пока ритм выключен.
 */
export function RhythmEnableCard() {
  const pathname = usePathname();
  const projectId = pathname?.match(/^\/app\/projects\/([^/?#]+)\/?$/)?.[1] ?? null;
  const [dismissed, setDismissed] = useState<string | null>(null);

  const { data: me } = useQuery({
    queryKey: ["me"],
    queryFn: () => api<{ user: User }>("/api/v1/auth/me"),
    staleTime: 60_000,
  });
  const { data: projectsData } = useQuery({
    queryKey: ["projects"],
    queryFn: () => api<{ items: Project[] }>("/api/v1/projects"),
    staleTime: 20_000,
  });

  useEffect(() => {
    if (!projectId) return;
    try {
      setDismissed(localStorage.getItem(dismissKey(projectId)) === "1" ? projectId : null);
    } catch {
      setDismissed(null);
    }
  }, [projectId]);

  const project = projectId ? projectsData?.items.find((p) => p.id === projectId) : undefined;
  if (!project || !me?.user) return null;
  const isOwner = project.members.some((m) => m.user_id === me.user.id && m.role === "admin");
  if (!isOwner || project.is_archived || project.rhythm?.enabled) return null;
  if (dismissed === project.id) return null;

  function dismiss() {
    if (!project) return;
    try {
      localStorage.setItem(dismissKey(project.id), "1");
    } catch {
      /* ignore */
    }
    setDismissed(project.id);
  }

  return (
    <div
      className="mb-3 flex flex-wrap items-center gap-x-3 gap-y-2 rounded-[var(--radius)] border border-hairline bg-[var(--surface)] px-3 py-2.5"
      data-testid="rhythm-enable-card"
    >
      <AppIcon name="circle-check" size={18} className="shrink-0 text-[var(--accent)]" />
      <div className="min-w-0 flex-1 basis-56">
        <p className="text-sm font-semibold text-foreground">Включите ежедневный чек-ин</p>
        <p className="text-xs text-muted">
          Команда ответит за 10 секунд, а задачи на доске обновятся сами. Настройки — в шестерёнке проекта.
        </p>
      </div>
      <div className="ml-auto flex items-center gap-1.5">
        <Button
          size="sm"
          onClick={() =>
            window.dispatchEvent(
              new CustomEvent(OPEN_PROJECT_SETTINGS_EVENT, { detail: { projectId: project.id } })
            )
          }
        >
          Настроить
        </Button>
        <Button size="sm" variant="ghost" onClick={dismiss} aria-label="Скрыть подсказку">
          Позже
        </Button>
      </div>
    </div>
  );
}

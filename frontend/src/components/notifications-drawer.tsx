"use client";

import { AppIcon } from "@/components/ui/app-icon";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { api } from "@/lib/api";
import type { NotificationItem } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

function sanitize(text: string | null | undefined) {
  if (!text) return "";
  return text.replace(/\[demo-seed\]\s*/gi, "").replace(/\s+/g, " ").trim();
}

function relativeTime(iso: string) {
  const dt = new Date(iso);
  if (Number.isNaN(dt.getTime())) return "";
  const diff = Date.now() - dt.getTime();
  const min = Math.floor(diff / 60000);
  if (min < 1) return "только что";
  if (min < 60) return `${min} мин`;
  const h = Math.floor(min / 60);
  if (h < 24) return `${h} ч`;
  const d = Math.floor(h / 24);
  if (d < 7) return `${d} д`;
  return dt.toLocaleDateString("ru-RU", { day: "2-digit", month: "2-digit" });
}

export function NotificationsDrawer({
  open,
  onClose,
}: {
  open: boolean;
  onClose: () => void;
}) {
  const router = useRouter();
  const qc = useQueryClient();

  const { data, isLoading, refetch } = useQuery({
    queryKey: ["notifications"],
    queryFn: () =>
      api<{ items: NotificationItem[]; unread: number }>("/api/v1/notifications?page_size=50"),
    staleTime: 10_000,
    enabled: open,
    refetchInterval: open ? 20_000 : false,
  });

  useEffect(() => {
    if (!open) return;
    refetch();
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open, onClose, refetch]);

  if (!open) return null;

  const items = data?.items ?? [];
  const unread = data?.unread ?? 0;

  async function openItem(n: NotificationItem) {
    if (!n.is_read) {
      await api(`/api/v1/notifications/${n.id}/read`, { method: "POST" });
      qc.invalidateQueries({ queryKey: ["notifications"] });
    }
    onClose();
    if (n.project_id && n.task_id) router.push(`/projects/${n.project_id}?task=${n.task_id}`);
    else if (n.project_id) router.push(`/projects/${n.project_id}`);
  }

  return (
    <div className="fixed inset-0 z-50 flex justify-end" role="dialog" aria-modal="true" aria-label="Уведомления">
      <button type="button" className="absolute inset-0 bg-black/25" aria-label="Закрыть" onClick={onClose} />
      <aside
        className={cn(
          "relative z-10 flex h-full w-full flex-col border-l border-hairline bg-[var(--surface)] shadow-sm",
          "md:w-[420px] md:max-w-[480px]"
        )}
      >
        <div className="flex items-center justify-between gap-2 border-b border-hairline px-4 py-3">
          <div>
            <h2 className="text-base font-semibold">Уведомления</h2>
            <p className="text-xs text-muted">
              {unread > 0 ? `${unread} непрочитанных` : "Все прочитаны"}
            </p>
          </div>
          <div className="flex items-center gap-1">
            {unread > 0 && (
              <Button
                type="button"
                variant="ghost"
                size="sm"
                onClick={async () => {
                  await api("/api/v1/notifications/read-all", { method: "POST" });
                  qc.invalidateQueries({ queryKey: ["notifications"] });
                }}
              >
                Прочитать все
              </Button>
            )}
            <Button variant="ghost" size="icon" aria-label="Закрыть" onClick={onClose}>
              <AppIcon name="close" size={20} />
            </Button>
          </div>
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto">
          {isLoading && <p className="px-4 py-10 text-center text-sm text-muted">Загрузка…</p>}
          {!isLoading && items.length === 0 && (
            <div className="px-4 py-16 text-center">
              <p className="text-sm font-medium text-foreground">Пока нет уведомлений</p>
              <p className="mt-1 text-xs text-muted">
                Здесь появятся назначения, приглашения и заявки по проектам.
              </p>
            </div>
          )}
          {items.map((n) => {
            const title = sanitize(n.title) || "Уведомление";
            const body = sanitize(n.body);
            return (
              <button
                key={n.id}
                type="button"
                className={cn(
                  "block w-full border-b border-hairline px-4 py-3.5 text-left last:border-b-0",
                  n.is_read ? "opacity-80" : "bg-[var(--accent-soft)]"
                )}
                onClick={() => openItem(n)}
              >
                <div className="flex items-start gap-2.5">
                  {!n.is_read && (
                    <span className="mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full bg-[var(--accent)]" />
                  )}
                  <div className={cn("min-w-0 flex-1", n.is_read && "pl-3.5")}>
                    <p className="text-[13px] font-medium leading-snug text-foreground">{title}</p>
                    {body && <p className="mt-0.5 line-clamp-3 text-xs text-muted">{body}</p>}
                    <p className="mt-1.5 text-[11px] text-muted">{relativeTime(n.created_at)}</p>
                  </div>
                </div>
              </button>
            );
          })}
        </div>
      </aside>
    </div>
  );
}

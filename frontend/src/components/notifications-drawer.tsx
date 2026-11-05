"use client";

import { AppIcon } from "@/components/ui/app-icon";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { api } from "@/lib/api";
import {
  DATE_GROUP_LABEL,
  notificationCardModel,
  notificationDateGroup,
  type DateGroupKey,
  type NotificationCardModel,
} from "@/lib/notification-display";
import type { NotificationItem } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

type Filter = "all" | "unread";

export function NotificationsDrawer({
  open,
  onClose,
}: {
  open: boolean;
  onClose: () => void;
}) {
  const router = useRouter();
  const qc = useQueryClient();
  const [filter, setFilter] = useState<Filter>("all");

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

  const unread = data?.unread ?? 0;

  const filtered = useMemo(() => {
    const items = data?.items ?? [];
    return filter === "unread" ? items.filter((n) => !n.is_read) : items;
  }, [data?.items, filter]);

  const groups = useMemo(() => {
    const order: DateGroupKey[] = ["today", "yesterday", "earlier"];
    const map: Record<DateGroupKey, NotificationItem[]> = {
      today: [],
      yesterday: [],
      earlier: [],
    };
    for (const n of filtered) {
      map[notificationDateGroup(n.created_at)].push(n);
    }
    return order
      .map((key) => ({ key, label: DATE_GROUP_LABEL[key], items: map[key] }))
      .filter((g) => g.items.length > 0);
  }, [filtered]);

  if (!open) return null;

  async function openItem(n: NotificationItem) {
    if (!n.is_read) {
      await api(`/api/v1/notifications/${n.id}/read`, { method: "POST" });
      qc.invalidateQueries({ queryKey: ["notifications"] });
    }
    onClose();
    if (n.project_id && n.task_id) router.push(`/app/projects/${n.project_id}?task=${n.task_id}`);
    else if (n.project_id) router.push(`/app/projects/${n.project_id}`);
  }

  return (
    <div className="fixed inset-0 z-50 flex justify-end" role="dialog" aria-modal="true" aria-label="Уведомления">
      <button type="button" className="absolute inset-0 bg-black/25" aria-label="Закрыть" onClick={onClose} />
      <aside
        className={cn(
          "relative z-10 flex h-full w-full flex-col border-l border-hairline bg-[var(--background)] shadow-sm",
          "md:w-[420px] md:max-w-[480px]"
        )}
      >
        <div className="flex items-center justify-between gap-2 border-b border-hairline bg-[var(--surface)] px-4 py-3">
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

        <div className="flex gap-2 px-3 pb-2 pt-2.5">
          {(
            [
              ["all", "Все"],
              ["unread", "Непрочитанные"],
            ] as const
          ).map(([id, label]) => (
            <button
              key={id}
              type="button"
              onClick={() => setFilter(id)}
              className={cn(
                "rounded-full px-3 py-[7px] text-[13px] font-semibold transition",
                filter === id
                  ? "bg-[var(--accent)] text-white"
                  : "bg-[var(--surface-2)] text-muted hover:text-foreground"
              )}
            >
              {label}
            </button>
          ))}
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto px-3 pb-6 pt-1">
          {isLoading && <p className="px-1 py-10 text-center text-sm text-muted">Загрузка…</p>}
          {!isLoading && filtered.length === 0 && (
            <div className="px-1 py-16 text-center">
              <p className="text-sm font-medium text-foreground">
                {filter === "unread" ? "Нет непрочитанных" : "Пока нет уведомлений"}
              </p>
              <p className="mt-1 text-xs text-muted">
                Здесь появятся назначения, изменения статусов и приглашения
              </p>
            </div>
          )}
          {groups.map((group) => (
            <section key={group.key} className="mb-3">
              <h3 className="mb-2 px-1 text-[11px] font-semibold uppercase tracking-[0.04em] text-muted">
                {group.label}
              </h3>
              <ul className="space-y-2">
                {group.items.map((n) => (
                  <li key={n.id}>
                    <NotificationCardButton
                      card={notificationCardModel(n)}
                      onClick={() => void openItem(n)}
                    />
                  </li>
                ))}
              </ul>
            </section>
          ))}
        </div>
      </aside>
    </div>
  );
}

/** Same structure as mobile `_NotificationCard`. */
function NotificationCardButton({
  card,
  onClick,
}: {
  card: NotificationCardModel;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "flex w-full gap-2.5 rounded-[var(--radius-lg)] border px-3 py-[11px] text-left transition",
        card.isRead
          ? "border-hairline bg-[var(--surface)] shadow-none"
          : "border-[#b5cad6] bg-[#dce8ee] shadow-sm dark:border-[color-mix(in_srgb,var(--accent)_45%,transparent)] dark:bg-[#243840]"
      )}
    >
      <span className="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-white text-[var(--accent)] dark:bg-[var(--surface-2)]">
        <AppIcon name={card.icon} size={18} />
      </span>
      <span className="min-w-0 flex-1">
        <span className="flex items-start gap-2">
          <span className="min-w-0 flex-1 text-[13px] font-semibold leading-snug text-foreground">
            {card.kindLabel}
          </span>
          <span className="flex shrink-0 items-center gap-1.5 pt-0.5">
            {card.time ? <span className="text-[11px] font-medium text-muted">{card.time}</span> : null}
            {!card.isRead && <span className="h-[7px] w-[7px] rounded-full bg-[var(--accent)]" />}
          </span>
        </span>
        {card.subject ? (
          <span className="mt-1 block text-[13.5px] font-semibold leading-snug text-foreground">
            {card.subject}
          </span>
        ) : null}
        {card.detail ? (
          <span className="mt-[3px] block text-[12.5px] leading-snug text-muted">{card.detail}</span>
        ) : null}
        {card.project ? (
          <span className="mt-0.5 block text-[12.5px] leading-snug text-muted">{card.project}</span>
        ) : null}
      </span>
    </button>
  );
}

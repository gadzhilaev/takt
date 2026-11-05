"use client";

import { AppIcon } from "@/components/ui/app-icon";
import { api } from "@/lib/api";
import { notificationCardModel } from "@/lib/notification-display";
import type { NotificationItem } from "@/lib/types";
import { enableWebPush, getPushStatus } from "@/lib/web-push";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { cn } from "@/lib/utils";

type ToastItem = {
  id: string;
  title: string;
  body: string;
  projectId: string | null;
  taskId: string | null;
};

function showBrowserNotification(n: NotificationItem, toast: ToastItem) {
  if (typeof window === "undefined" || !("Notification" in window)) return;
  if (Notification.permission !== "granted") return;
  try {
    const note = new Notification(toast.title, {
      body: toast.body || undefined,
      tag: `takt-${n.id}`,
      icon: "/favicon.svg",
    });
    note.onclick = () => {
      window.focus();
      note.close();
      if (n.project_id && n.task_id) {
        window.location.href = `/app/projects/${n.project_id}?task=${n.task_id}`;
      } else if (n.project_id) {
        window.location.href = `/app/projects/${n.project_id}`;
      }
    };
  } catch {
    /* ignore */
  }
}

function toastFromNotification(n: NotificationItem): ToastItem {
  const card = notificationCardModel(n);
  // Mobile toast: title = task name, body = «X назначила…» + project.
  const title = card.subject || card.kindLabel || "Уведомление";
  const body = [card.detail, card.project].filter(Boolean).join("\n");
  return {
    id: n.id,
    title,
    body,
    projectId: n.project_id,
    taskId: n.task_id,
  };
}

export function NotificationToasts() {
  const router = useRouter();
  const qc = useQueryClient();
  const seenIds = useRef<Set<string> | null>(null);
  const [toasts, setToasts] = useState<ToastItem[]>([]);

  const { data } = useQuery({
    queryKey: ["notifications"],
    queryFn: () =>
      api<{ items: NotificationItem[]; unread: number }>("/api/v1/notifications?page_size=30"),
    staleTime: 8_000,
    refetchInterval: 20_000,
    refetchOnWindowFocus: true,
  });

  useEffect(() => {
    void (async () => {
      try {
        const status = await getPushStatus();
        if (status.supported && status.permission === "granted" && status.configured && !status.subscribed) {
          await enableWebPush();
        }
      } catch {
        /* ignore */
      }
    })();
  }, []);

  useEffect(() => {
    const items = data?.items ?? [];
    if (!items.length && seenIds.current == null) {
      seenIds.current = new Set();
      return;
    }
    if (seenIds.current == null) {
      seenIds.current = new Set(items.map((n) => n.id));
      return;
    }
    const fresh = items.filter((n) => !seenIds.current!.has(n.id));
    if (!fresh.length) return;
    for (const n of fresh) seenIds.current.add(n.id);
    const incoming = [...fresh].reverse();
    for (const n of incoming) {
      const toast = toastFromNotification(n);
      showBrowserNotification(n, toast);
      setToasts((prev) => [toast, ...prev].slice(0, 4));
      window.setTimeout(() => {
        setToasts((prev) => prev.filter((t) => t.id !== toast.id));
      }, 6500);
    }
  }, [data?.items]);

  async function openToast(t: ToastItem) {
    try {
      await api(`/api/v1/notifications/${t.id}/read`, { method: "POST" });
      qc.invalidateQueries({ queryKey: ["notifications"] });
    } catch {
      /* ignore */
    }
    setToasts((prev) => prev.filter((x) => x.id !== t.id));
    if (t.projectId && t.taskId) router.push(`/app/projects/${t.projectId}?task=${t.taskId}`);
    else if (t.projectId) router.push(`/app/projects/${t.projectId}`);
  }

  if (!toasts.length) return null;

  return (
    <div
      className="pointer-events-none fixed inset-x-0 bottom-0 z-[90] flex flex-col items-center gap-2 p-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] sm:items-end sm:p-4"
      aria-live="polite"
    >
      {toasts.map((t) => (
        <button
          key={t.id}
          type="button"
          onClick={() => void openToast(t)}
          className={cn(
            "pointer-events-auto flex w-full max-w-md items-start gap-2.5 rounded-[var(--radius-lg)] border border-hairline",
            "bg-[var(--surface)] px-3 py-3 text-left shadow-md transition hover:border-[var(--accent)]",
            "animate-in slide-in-from-bottom-2 fade-in duration-200"
          )}
        >
          <span className="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-[10px] bg-[color-mix(in_srgb,var(--accent)_12%,transparent)] text-[var(--accent)]">
            <AppIcon name="notifications" size={18} />
          </span>
          <span className="min-w-0 flex-1">
            <span className="block text-[13px] font-semibold leading-snug text-foreground">{t.title}</span>
            {t.body ? (
              <span className="mt-0.5 block whitespace-pre-line text-xs leading-snug text-muted line-clamp-3">
                {t.body}
              </span>
            ) : null}
          </span>
          <span
            role="presentation"
            className="shrink-0 rounded p-1 text-muted hover:bg-[var(--surface-2)]"
            onClick={(e) => {
              e.stopPropagation();
              setToasts((prev) => prev.filter((x) => x.id !== t.id));
            }}
          >
            <AppIcon name="close" size={14} />
          </span>
        </button>
      ))}
    </div>
  );
}

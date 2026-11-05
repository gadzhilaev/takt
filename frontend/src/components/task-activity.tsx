"use client";

import { UserAvatar } from "@/components/user-avatar";
import { api } from "@/lib/api";
import { formatCreatedAt } from "@/lib/format-created-at";
import { cn } from "@/lib/utils";
import { useQuery } from "@tanstack/react-query";
import { useState } from "react";

export type TaskActivityItem = {
  id: string;
  action: string;
  field: string | null;
  old_value: string | null;
  new_value: string | null;
  old_label: string | null;
  new_label: string | null;
  summary: string;
  user: { id: string; name: string; avatar_url: string | null };
  created_at: string;
};

function isColumnMove(item: TaskActivityItem) {
  const a = (item.action || "").toLowerCase();
  return a === "moved" || a === "status_changed" || item.field === "status_id";
}

function moveCountLabel(n: number) {
  const mod10 = n % 10;
  const mod100 = n % 100;
  if (mod10 === 1 && mod100 !== 11) return "перенос";
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return "переноса";
  return "переносов";
}

/** Collapsible history — only column (status) moves. */
export function TaskActivityPanel({ taskId }: { taskId: string }) {
  const [open, setOpen] = useState(false);
  const { data, isLoading, isError } = useQuery({
    queryKey: ["task-activity", taskId],
    queryFn: () => api<{ items: TaskActivityItem[] }>(`/api/v1/tasks/${taskId}/activity`),
  });

  const items = (data?.items ?? []).filter(isColumnMove);

  if (!isLoading && !isError && items.length === 0) {
    return null;
  }

  const subtitle = isLoading
    ? "Загрузка…"
    : isError
      ? "Не удалось загрузить"
      : `${items.length} ${moveCountLabel(items.length)}`;

  return (
    <div className="overflow-hidden rounded-[var(--radius)] border border-hairline bg-[var(--surface-2)]">
      <button
        type="button"
        className="flex w-full items-center justify-between gap-2 px-3 py-2.5 text-left"
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
      >
        <span className="min-w-0">
          <span className="block text-[13px] font-semibold text-foreground">История столбцов</span>
          <span className="block text-[12px] text-muted">{subtitle}</span>
        </span>
        <span className={cn("text-muted transition", open && "rotate-180")} aria-hidden>
          ▾
        </span>
      </button>
      {open && (
        <div className="space-y-2.5 border-t border-hairline px-3 py-2.5">
          {isError && <p className="text-sm text-[var(--danger)]">Не удалось загрузить историю</p>}
          {isLoading && <p className="text-sm text-muted">Загрузка…</p>}
          {items.map((item) => {
            const when = formatCreatedAt(item.created_at);
            return (
              <div key={item.id} className="flex gap-2.5">
                <UserAvatar name={item.user.name} avatarUrl={item.user.avatar_url} size={6} />
                <div className="min-w-0 flex-1 pt-0.5">
                  <p className="text-[13px] leading-snug text-foreground">
                    <span className="font-semibold">{item.user.name}</span>{" "}
                    <span>{item.summary}</span>
                  </p>
                  {when && <p className="mt-0.5 text-[11px] text-muted">{when}</p>}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

"use client";

import { UserAvatar } from "@/components/user-avatar";
import { api } from "@/lib/api";
import { formatCreatedAt } from "@/lib/format-created-at";
import { useQuery } from "@tanstack/react-query";

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

export function TaskActivityPanel({ taskId }: { taskId: string }) {
  const { data, isLoading, isError } = useQuery({
    queryKey: ["task-activity", taskId],
    queryFn: () => api<{ items: TaskActivityItem[] }>(`/api/v1/tasks/${taskId}/activity`),
  });

  const items = data?.items ?? [];

  return (
    <div className="space-y-2">
      <p className="label-text mb-0">История</p>
      {isLoading && <p className="text-sm text-muted">Загрузка…</p>}
      {isError && <p className="text-sm text-[var(--danger)]">Не удалось загрузить историю</p>}
      {!isLoading && !isError && items.length === 0 && (
        <p className="text-sm text-muted">Пока нет событий</p>
      )}
      {items.length > 0 && (
        <ul className="space-y-2.5">
          {items.map((item) => {
            const when = formatCreatedAt(item.created_at);
            return (
              <li key={item.id} className="flex gap-2.5">
                <UserAvatar name={item.user.name} avatarUrl={item.user.avatar_url} size={6} />
                <div className="min-w-0 flex-1 pt-0.5">
                  <p className="text-[13px] leading-snug text-foreground">
                    <span className="font-semibold">{item.user.name}</span>{" "}
                    <span>{item.summary}</span>
                  </p>
                  {when && <p className="mt-0.5 text-[11px] text-muted">{when}</p>}
                </div>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}

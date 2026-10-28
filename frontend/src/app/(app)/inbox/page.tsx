"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { api } from "@/lib/api";
import type { NotificationItem } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { ErrorState } from "@/components/ui/error-state";
import { EmptyState } from "@/components/ui/empty-state";
import { Skeleton } from "@/components/ui/skeleton";

export default function InboxPage() {
  const qc = useQueryClient();
  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ["notifications"],
    queryFn: () => api<{ items: NotificationItem[]; unread: number }>("/api/v1/notifications?page_size=100"),
  });
  const markAll = useMutation({
    mutationFn: () => api("/api/v1/notifications/read-all", { method: "POST" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["notifications"] }),
  });

  if (isLoading) return <Skeleton className="h-40 w-full" />;
  if (isError) return <ErrorState message={(error as Error).message} onRetry={() => refetch()} />;

  const items = data?.items ?? [];

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Уведомления</h1>
        <Button variant="secondary" size="sm" onClick={() => markAll.mutate()} disabled={!data?.unread}>
          Прочитать все
        </Button>
      </div>
      {!items.length ? (
        <EmptyState title="Пока тихо" description="Упоминания и назначения появятся здесь" />
      ) : (
        <ul className="space-y-2">
          {items.map((n) => (
            <li
              key={n.id}
              className={`surface-panel p-3.5 ${n.is_read ? "opacity-70" : "border-[color-mix(in_srgb,var(--accent)_35%,var(--border))]"}`}
            >
              <div className="flex items-start justify-between gap-3">
                <div>
                  <div className="font-medium">{n.title}</div>
                  {n.body && <p className="mt-1 text-sm text-muted">{n.body}</p>}
                  <div className="mt-2 text-xs text-muted">
                    {new Date(n.created_at).toLocaleString("ru-RU")}
                    {n.task_id && (
                      <>
                        {" · "}
                        <Link href={`/tasks/${n.task_id}`} className="font-medium text-[var(--accent)] hover:underline">
                          Открыть задачу
                        </Link>
                      </>
                    )}
                  </div>
                </div>
                {!n.is_read && (
                  <Button
                    size="sm"
                    variant="ghost"
                    onClick={async () => {
                      await api(`/api/v1/notifications/${n.id}/read`, { method: "POST" });
                      qc.invalidateQueries({ queryKey: ["notifications"] });
                    }}
                  >
                    Прочитано
                  </Button>
                )}
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

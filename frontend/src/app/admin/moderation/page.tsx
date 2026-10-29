"use client";

import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";

type Report = {
  id: string;
  reason_code: string;
  status: string;
  target_type: string;
  target_id: string;
  version: number;
};

export default function AdminModerationPage() {
  const { data, isLoading, error } = useQuery({
    queryKey: ["platform-moderation"],
    queryFn: () => api<{ items: Report[] }>("/api/v1/platform/moderation/reports"),
  });

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold tracking-tight">Модерация</h1>
      <p className="text-[13px] text-muted">Очередь жалоб. Решения через API с optimistic concurrency (version).</p>
      {isLoading && <p className="text-sm text-muted">Загрузка…</p>}
      {error && <p className="text-sm text-[var(--danger)]">{(error as Error).message}</p>}
      {(data?.items ?? []).length === 0 && !isLoading ? (
        <p className="text-[13px] text-muted">Открытых жалоб нет.</p>
      ) : (
        <ul className="space-y-2">
          {(data?.items ?? []).map((r) => (
            <li key={r.id} className="rounded-[var(--radius)] border border-[var(--border)] bg-white p-3 text-[13px]">
              <p className="font-medium">
                {r.reason_code} · {r.status}
              </p>
              <p className="text-muted">
                {r.target_type}/{r.target_id} · v{r.version}
              </p>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

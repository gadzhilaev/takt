"use client";

import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";

export default function AdminSystemPage() {
  const { data, isLoading, error } = useQuery({
    queryKey: ["platform-health"],
    queryFn: () => api<Record<string, unknown>>("/api/v1/platform/system/health"),
  });

  if (isLoading) return <p className="text-sm text-muted">Загрузка…</p>;
  if (error) return <p className="text-sm text-[var(--danger)]">{(error as Error).message}</p>;

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold tracking-tight">Система</h1>
      <pre className="overflow-x-auto rounded-[var(--radius)] border border-[var(--border)] bg-white p-4 text-[12px]">
        {JSON.stringify(data, null, 2)}
      </pre>
      <p className="text-[11px] text-muted">Секреты и ключи не включаются в ответ.</p>
    </div>
  );
}

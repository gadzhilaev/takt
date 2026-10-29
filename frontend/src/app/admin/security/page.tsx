"use client";

import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";

type AuditItem = {
  id: string;
  created_at?: string;
  action: string;
  details?: string | null;
};

export default function AdminSecurityPage() {
  const { data, isLoading, error } = useQuery({
    queryKey: ["platform-audit"],
    queryFn: () => api<{ items: AuditItem[] }>("/api/v1/platform/security/audit"),
  });

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold tracking-tight">Безопасность</h1>
      <ul className="list-disc space-y-1 pl-5 text-[13px] text-muted">
        <li>Роли платформы: support / moderator / admin / super_admin (не project_admin).</li>
        <li>
          Назначение super_admin — только CLI: <code>python -m app.cli grant-super-admin --email …</code>
        </li>
        <li>MFA для админов: схема в БД готова; UI enrollment — следующий этап.</li>
        <li>Rate limit на login/OAuth через SlowAPI.</li>
      </ul>
      <h2 className="text-[14px] font-semibold">Журнал действий</h2>
      {isLoading && <p className="text-sm text-muted">Загрузка…</p>}
      {error && <p className="text-sm text-[var(--danger)]">{(error as Error).message}</p>}
      <ul className="space-y-1 text-[12px]">
        {(data?.items ?? []).map((a) => (
          <li key={a.id} className="border-b border-[var(--border)] py-1.5">
            {a.created_at} · {a.action}
            {a.details ? ` — ${a.details}` : ""}
          </li>
        ))}
      </ul>
    </div>
  );
}

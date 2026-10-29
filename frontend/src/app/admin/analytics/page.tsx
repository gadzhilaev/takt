"use client";

import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";

type Analytics = {
  note?: string;
  registrations: { day: string; count: number }[];
  projects_created: { day: string; count: number }[];
  tasks_created: { day: string; count: number }[];
  tasks_completed: unknown;
};

export default function AdminAnalyticsPage() {
  const { data, isLoading, error } = useQuery({
    queryKey: ["platform-analytics"],
    queryFn: () => api<Analytics>("/api/v1/platform/analytics?days=30"),
  });

  if (isLoading) return <p className="text-sm text-muted">Загрузка…</p>;
  if (error) return <p className="text-sm text-[var(--danger)]">{(error as Error).message}</p>;

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold tracking-tight">Аналитика</h1>
      <p className="text-[13px] text-muted">{data?.note}</p>
      <section className="rounded-[var(--radius)] border border-[var(--border)] bg-white p-4">
        <h2 className="text-[14px] font-semibold">Регистрации</h2>
        <Series rows={data?.registrations ?? []} />
      </section>
      <section className="rounded-[var(--radius)] border border-[var(--border)] bg-white p-4">
        <h2 className="text-[14px] font-semibold">Проекты</h2>
        <Series rows={data?.projects_created ?? []} />
      </section>
      <section className="rounded-[var(--radius)] border border-[var(--border)] bg-white p-4">
        <h2 className="text-[14px] font-semibold">Задачи созданы</h2>
        <Series rows={data?.tasks_created ?? []} />
      </section>
      {data?.tasks_completed == null && (
        <p className="text-[12px] text-muted">Завершение задач и retention: данных пока нет (не подставляются нули).</p>
      )}
    </div>
  );
}

function Series({ rows }: { rows: { day: string; count: number }[] }) {
  if (!rows.length) return <p className="mt-2 text-[13px] text-muted">Нет данных за период.</p>;
  return (
    <ul className="mt-2 space-y-1 text-[13px] tabular-nums">
      {rows.map((r) => (
        <li key={r.day} className="flex justify-between border-b border-[var(--border)] py-1">
          <span>{r.day}</span>
          <span>{r.count}</span>
        </li>
      ))}
    </ul>
  );
}

"use client";

import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";

type Dash = {
  users_total: number;
  users_new_7d: number;
  projects_total: number;
  tasks_total: number;
  open_reports: number;
  active_blocks: number;
  dau: number;
  wau: number;
  mau: number;
  activity_by_day: { day: string | null; count: number }[];
  metrics_note: string;
};

function Card({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-[var(--radius)] border border-[#dce2e7] bg-white p-4">
      <p className="text-[12px] font-medium text-[#5a6573]">{label}</p>
      <p className="mt-2 text-2xl font-semibold tabular-nums tracking-tight text-[#202938]">{value}</p>
    </div>
  );
}

export default function AdminDashboardPage() {
  const { data, isLoading, error } = useQuery({
    queryKey: ["platform-dashboard"],
    queryFn: () => api<Dash>("/api/v1/platform/dashboard"),
  });

  if (isLoading) return <p className="text-sm text-muted">Загрузка…</p>;
  if (error) return <p className="text-sm text-[var(--danger)]">{(error as Error).message}</p>;
  if (!data) return null;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold tracking-tight text-[#202938]">Dashboard</h1>
        <p className="mt-1 text-[13px] text-[#5a6573]">Платформа Takt — сводные показатели</p>
      </div>
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Card label="Пользователи" value={data.users_total} />
        <Card label="Новые за 7 дней" value={data.users_new_7d} />
        <Card label="Проекты" value={data.projects_total} />
        <Card label="Задачи" value={data.tasks_total} />
        <Card label="DAU" value={data.dau} />
        <Card label="WAU" value={data.wau} />
        <Card label="MAU" value={data.mau} />
        <Card label="Жалобы / блокировки" value={`${data.open_reports} / ${data.active_blocks}`} />
      </div>
      <section className="rounded-[var(--radius)] border border-[#dce2e7] bg-white p-4">
        <h2 className="text-[14px] font-semibold text-[#202938]">Активность по дням</h2>
        {data.activity_by_day.length === 0 ? (
          <p className="mt-3 text-[13px] text-[#5a6573]">Пока нет событий активности.</p>
        ) : (
          <ul className="mt-3 space-y-1 text-[13px] tabular-nums text-[#202938]">
            {data.activity_by_day.map((d) => (
              <li key={String(d.day)} className="flex justify-between border-b border-[#dce2e7] py-1.5">
                <span>{d.day}</span>
                <span className="font-medium">{d.count}</span>
              </li>
            ))}
          </ul>
        )}
        <p className="mt-4 text-[11px] leading-snug text-[#5a6573]">{data.metrics_note}</p>
      </section>
    </div>
  );
}

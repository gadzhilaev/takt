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

function Card({
  label,
  hint,
  value,
}: {
  label: string;
  hint: string;
  value: string | number;
}) {
  return (
    <div className="rounded-[var(--radius)] border border-[#dce2e7] bg-white p-4">
      <p className="text-[12px] font-medium text-[#5a6573]">{label}</p>
      <p className="mt-2 text-2xl font-semibold tabular-nums tracking-tight text-[#202938]">{value}</p>
      <p className="mt-1.5 text-[11px] leading-snug text-[#5a6573]">{hint}</p>
    </div>
  );
}

function formatDay(iso: string | null): string {
  if (!iso) return "—";
  const d = new Date(`${iso}T12:00:00`);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString("ru-RU", { day: "numeric", month: "long", year: "numeric" });
}

export default function AdminDashboardPage() {
  const { data, isLoading, error } = useQuery({
    queryKey: ["platform-dashboard"],
    queryFn: () => api<Dash>("/api/v1/platform/dashboard"),
  });

  if (isLoading) return <p className="text-sm text-[#5a6573]">Загрузка…</p>;
  if (error) return <p className="text-sm text-[var(--danger)]">{(error as Error).message}</p>;
  if (!data) return null;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold tracking-tight text-[#202938]">Обзор платформы</h1>
        <p className="mt-1 text-[13px] text-[#5a6573]">
          Сколько людей, проектов и задач сейчас в Takt — и кто заходил недавно.
        </p>
      </div>
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Card
          label="Всего пользователей"
          hint="Зарегистрированные аккаунты в базе"
          value={data.users_total}
        />
        <Card
          label="Новые за неделю"
          hint="Аккаунты, созданные за последние 7 дней"
          value={data.users_new_7d}
        />
        <Card
          label="Проекты"
          hint="Все доски на платформе, включая демо"
          value={data.projects_total}
        />
        <Card
          label="Задачи"
          hint="Неудалённые задачи во всех проектах"
          value={data.tasks_total}
        />
        <Card
          label="Заходили за сутки"
          hint="Уникальные пользователи с входом за 24 часа"
          value={data.dau}
        />
        <Card
          label="Заходили за неделю"
          hint="Уникальные пользователи с входом за 7 дней"
          value={data.wau}
        />
        <Card
          label="Заходили за месяц"
          hint="Уникальные пользователи с входом за 30 дней"
          value={data.mau}
        />
        <Card
          label="Жалобы · блокировки"
          hint="Открытые жалобы · сейчас заблокированные аккаунты"
          value={`${data.open_reports} · ${data.active_blocks}`}
        />
      </div>
      <section className="rounded-[var(--radius)] border border-[#dce2e7] bg-white p-4">
        <h2 className="text-[14px] font-semibold text-[#202938]">Входы по дням</h2>
        <p className="mt-1 text-[12px] text-[#5a6573]">
          Сколько раз фиксировались события входа за последние 14 дней (не уникальные люди).
        </p>
        {data.activity_by_day.length === 0 ? (
          <p className="mt-3 text-[13px] text-[#5a6573]">Пока нет записей о входах.</p>
        ) : (
          <ul className="mt-3 space-y-1 text-[13px] tabular-nums text-[#202938]">
            {data.activity_by_day.map((d) => (
              <li key={String(d.day)} className="flex justify-between border-b border-[#dce2e7] py-1.5">
                <span>{formatDay(d.day)}</span>
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

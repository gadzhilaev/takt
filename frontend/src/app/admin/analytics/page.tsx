"use client";

import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";

type DayCount = { day: string; count: number };

type Analytics = {
  days?: number;
  note?: string;
  registrations: DayCount[];
  projects_created: DayCount[];
  tasks_created: DayCount[];
  tasks_completed: unknown;
};

function formatDay(iso: string): string {
  const d = new Date(`${iso}T12:00:00`);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString("ru-RU", { day: "numeric", month: "short" });
}

function sum(rows: DayCount[]): number {
  return rows.reduce((acc, r) => acc + r.count, 0);
}

function SummaryCard({ label, value, hint }: { label: string; value: number; hint: string }) {
  return (
    <div className="rounded-[var(--radius)] border border-[#dce2e7] bg-white p-4">
      <p className="text-[12px] font-medium text-[#5a6573]">{label}</p>
      <p className="mt-2 text-2xl font-semibold tabular-nums tracking-tight text-[#202938]">{value}</p>
      <p className="mt-1 text-[11px] text-[#5a6573]">{hint}</p>
    </div>
  );
}

function Series({ title, hint, rows }: { title: string; hint: string; rows: DayCount[] }) {
  const total = sum(rows);
  const max = Math.max(1, ...rows.map((r) => r.count));

  return (
    <section className="rounded-[var(--radius)] border border-[#dce2e7] bg-white p-4">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <div>
          <h2 className="text-[14px] font-semibold text-[#202938]">{title}</h2>
          <p className="mt-0.5 text-[12px] text-[#5a6573]">{hint}</p>
        </div>
        <p className="text-[13px] font-semibold tabular-nums text-[#202938]">всего {total}</p>
      </div>
      {!rows.length ? (
        <p className="mt-3 text-[13px] text-[#5a6573]">За выбранный период событий нет.</p>
      ) : (
        <ul className="mt-3 space-y-2">
          {rows.map((r) => (
            <li key={r.day} className="grid grid-cols-[5.5rem_1fr_2rem] items-center gap-2 text-[13px]">
              <span className="tabular-nums text-[#5a6573]">{formatDay(r.day)}</span>
              <div className="h-2 overflow-hidden rounded-full bg-[#eef1f4]">
                <div
                  className="h-full rounded-full bg-[#315f72]"
                  style={{ width: `${Math.max(6, (r.count / max) * 100)}%` }}
                />
              </div>
              <span className="text-right font-medium tabular-nums text-[#202938]">{r.count}</span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

export default function AdminAnalyticsPage() {
  const { data, isLoading, error } = useQuery({
    queryKey: ["platform-analytics"],
    queryFn: () => api<Analytics>("/api/v1/platform/analytics?days=30"),
  });

  if (isLoading) return <p className="text-sm text-[#5a6573]">Загрузка…</p>;
  if (error) return <p className="text-sm text-[var(--danger)]">{(error as Error).message}</p>;
  if (!data) return null;

  const days = data.days ?? 30;

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-semibold tracking-tight text-[#202938]">Аналитика</h1>
        <p className="mt-1 text-[13px] text-[#5a6573]">
          Что происходило на платформе за последние {days} дней. Без выдуманных нулей.
        </p>
      </div>

      <div className="grid gap-3 sm:grid-cols-3">
        <SummaryCard
          label="Новые пользователи"
          value={sum(data.registrations)}
          hint={`за ${days} дн.`}
        />
        <SummaryCard
          label="Новые проекты"
          value={sum(data.projects_created)}
          hint={`за ${days} дн.`}
        />
        <SummaryCard
          label="Создано задач"
          value={sum(data.tasks_created)}
          hint="только количество, без текстов"
        />
      </div>

      <Series
        title="Регистрации по дням"
        hint="Сколько аккаунтов создали в каждый день"
        rows={data.registrations}
      />
      <Series
        title="Новые проекты по дням"
        hint="Сколько досок создали"
        rows={data.projects_created}
      />
      <Series
        title="Созданные задачи по дням"
        hint="Сколько задач добавили (названия не показываем)"
        rows={data.tasks_created}
      />

      <p className="text-[12px] leading-snug text-[#5a6573]">{data.note}</p>
    </div>
  );
}

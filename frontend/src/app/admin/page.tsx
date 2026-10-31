"use client";

import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { useSessionState } from "@/lib/use-session-state";

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
};

type DayCount = { day: string; count: number };

type Analytics = {
  days?: number;
  registrations: DayCount[];
  projects_created: DayCount[];
  tasks_created: DayCount[];
};

const RANGES = [7, 30, 90] as const;

function Stat({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-[var(--radius)] border border-[var(--border)] bg-white px-4 py-3">
      <p className="text-[12px] text-muted">{label}</p>
      <p className="mt-1 text-2xl font-semibold tabular-nums tracking-tight">{value}</p>
    </div>
  );
}

function sum(rows: DayCount[]): number {
  return rows.reduce((acc, r) => acc + r.count, 0);
}

function formatDay(iso: string): string {
  const d = new Date(`${iso}T12:00:00`);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString("ru-RU", { day: "numeric", month: "short" });
}

function Series({ title, rows }: { title: string; rows: DayCount[] }) {
  const max = Math.max(1, ...rows.map((r) => r.count));
  return (
    <section className="rounded-[var(--radius)] border border-[var(--border)] bg-white p-4">
      <div className="flex items-baseline justify-between gap-2">
        <h2 className="text-[14px] font-semibold">{title}</h2>
        <span className="text-[13px] font-semibold tabular-nums">{sum(rows)}</span>
      </div>
      {!rows.length ? (
        <p className="mt-3 text-[13px] text-muted">Нет данных</p>
      ) : (
        <ul className="mt-3 space-y-1.5">
          {rows.map((r) => (
            <li key={r.day} className="grid grid-cols-[4.5rem_1fr_1.5rem] items-center gap-2 text-[13px]">
              <span className="tabular-nums text-muted">{formatDay(r.day)}</span>
              <div className="h-1.5 overflow-hidden rounded-full bg-[#eef1f4]">
                <div
                  className="h-full rounded-full bg-[var(--accent)]"
                  style={{ width: `${Math.max(6, (r.count / max) * 100)}%` }}
                />
              </div>
              <span className="text-right tabular-nums">{r.count}</span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

export default function AdminDashboardPage() {
  const [days, setDays] = useSessionState<number>("takt-admin-overview-days", 30);

  const dash = useQuery({
    queryKey: ["platform-dashboard"],
    queryFn: () => api<Dash>("/api/v1/platform/dashboard"),
  });
  const analytics = useQuery({
    queryKey: ["platform-analytics", days],
    queryFn: () => api<Analytics>(`/api/v1/platform/analytics?days=${days}`),
    placeholderData: keepPreviousData,
  });

  if (dash.isLoading) return <p className="text-sm text-muted">Загрузка…</p>;
  if (dash.error) return <p className="text-sm text-[var(--danger)]">{(dash.error as Error).message}</p>;
  if (!dash.data) return null;

  const d = dash.data;
  const a = analytics.data;

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <h1 className="text-xl font-semibold tracking-tight">Обзор</h1>
        <div className="flex gap-1.5">
          {RANGES.map((n) => (
            <Button
              key={n}
              type="button"
              size="sm"
              variant={days === n ? "default" : "secondary"}
              onClick={() => setDays(n)}
            >
              {n} дн.
            </Button>
          ))}
        </div>
      </div>

      <div className="grid gap-3 sm:grid-cols-3 lg:grid-cols-6">
        <Stat label="Пользователи" value={d.users_total} />
        <Stat label="Новые / 7д" value={d.users_new_7d} />
        <Stat label="Проекты" value={d.projects_total} />
        <Stat label="Задачи" value={d.tasks_total} />
        <Stat label="DAU / WAU / MAU" value={`${d.dau} / ${d.wau} / ${d.mau}`} />
        <Stat label="Жалобы · блок." value={`${d.open_reports} · ${d.active_blocks}`} />
      </div>

      {analytics.isLoading && !a ? (
        <p className="text-sm text-muted">Загрузка аналитики…</p>
      ) : a ? (
        <div className="grid gap-3 lg:grid-cols-3">
          <Series title="Регистрации" rows={a.registrations} />
          <Series title="Новые проекты" rows={a.projects_created} />
          <Series title="Созданные задачи" rows={a.tasks_created} />
        </div>
      ) : null}
    </div>
  );
}

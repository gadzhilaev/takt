"use client";

import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { useSessionState } from "@/lib/use-session-state";

type DayCount = { day: string; count: number };

type Analytics = {
  days?: number;
  note?: string;
  registrations: DayCount[];
  projects_created: DayCount[];
  tasks_created: DayCount[];
  tasks_completed: unknown;
};

const RANGES = [7, 30, 90] as const;

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
    <div className="rounded-[var(--radius)] border border-[var(--border)] bg-white p-4">
      <p className="text-[12px] font-medium text-muted">{label}</p>
      <p className="mt-2 text-2xl font-semibold tabular-nums tracking-tight">{value}</p>
      <p className="mt-1 text-[11px] text-muted">{hint}</p>
    </div>
  );
}

function Series({ title, hint, rows }: { title: string; hint: string; rows: DayCount[] }) {
  const total = sum(rows);
  const max = Math.max(1, ...rows.map((r) => r.count));

  return (
    <section className="rounded-[var(--radius)] border border-[var(--border)] bg-white p-4">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <div>
          <h2 className="text-[14px] font-semibold">{title}</h2>
          <p className="mt-0.5 text-[12px] text-muted">{hint}</p>
        </div>
        <p className="text-[13px] font-semibold tabular-nums">всего {total}</p>
      </div>
      {!rows.length ? (
        <p className="mt-3 text-[13px] text-muted">За выбранный период событий нет.</p>
      ) : (
        <ul className="mt-3 space-y-2">
          {rows.map((r) => (
            <li key={r.day} className="grid grid-cols-[5.5rem_1fr_2rem] items-center gap-2 text-[13px]">
              <span className="tabular-nums text-muted">{formatDay(r.day)}</span>
              <div className="h-2 overflow-hidden rounded-full bg-[#eef1f4]">
                <div
                  className="h-full rounded-full bg-[var(--accent)]"
                  style={{ width: `${Math.max(6, (r.count / max) * 100)}%` }}
                />
              </div>
              <span className="text-right font-medium tabular-nums">{r.count}</span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

export default function AdminAnalyticsPage() {
  const [days, setDays] = useSessionState<number>("takt-admin-analytics-days", 30);
  const { data, isLoading, error } = useQuery({
    queryKey: ["platform-analytics", days],
    queryFn: () => api<Analytics>(`/api/v1/platform/analytics?days=${days}`),
  });

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold tracking-tight">Аналитика</h1>
          <p className="mt-1 text-[13px] text-muted">
            Факты из базы за выбранный период — без выдуманных метрик.
          </p>
        </div>
        <div className="flex gap-1.5">
          {RANGES.map((d) => (
            <Button
              key={d}
              type="button"
              size="sm"
              variant={days === d ? "default" : "secondary"}
              onClick={() => setDays(d)}
            >
              {d} дн.
            </Button>
          ))}
        </div>
      </div>

      {isLoading ? <p className="text-sm text-muted">Загрузка…</p> : null}
      {error ? <p className="text-sm text-[var(--danger)]">{(error as Error).message}</p> : null}

      {data ? (
        <>
          <div className="grid gap-3 sm:grid-cols-3">
            <SummaryCard
              label="Новые пользователи"
              value={sum(data.registrations)}
              hint={`за ${data.days ?? days} дн.`}
            />
            <SummaryCard
              label="Новые проекты"
              value={sum(data.projects_created)}
              hint={`за ${data.days ?? days} дн.`}
            />
            <SummaryCard
              label="Создано задач"
              value={sum(data.tasks_created)}
              hint="только количество, без текстов"
            />
          </div>

          <Series
            title="Регистрации по дням"
            hint="Сколько аккаунтов создали"
            rows={data.registrations}
          />
          <Series
            title="Новые проекты по дням"
            hint="Сколько досок создали"
            rows={data.projects_created}
          />
          <Series
            title="Созданные задачи по дням"
            hint="Названия задач не показываем"
            rows={data.tasks_created}
          />

          {data.note ? <p className="text-[12px] leading-snug text-muted">{data.note}</p> : null}
        </>
      ) : null}
    </div>
  );
}

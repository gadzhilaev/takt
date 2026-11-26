"use client";

import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { useSessionState } from "@/lib/use-session-state";
import Link from "next/link";
import { ArrowRight, FolderKanban, ShieldAlert, UsersRound } from "lucide-react";

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
  active_users: DayCount[];
  registrations: DayCount[];
  projects_created: DayCount[];
  tasks_created: DayCount[];
};

const RANGES = [7, 30, 90] as const;

function Stat({
  label,
  value,
  hint,
  icon: Icon,
  accent = false,
}: {
  label: string;
  value: string | number;
  hint?: string;
  icon: typeof UsersRound;
  accent?: boolean;
}) {
  return (
    <div className="rounded-xl border border-[#dce2e7] bg-white p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-[12px] font-medium text-[#667485]">{label}</p>
          {hint ? <p className="mt-1 text-[11px] leading-snug text-[#81909d]">{hint}</p> : null}
          <p className="mt-3 text-[1.75rem] font-semibold leading-none tabular-nums tracking-tight text-[#202938]">{value}</p>
        </div>
        <span className={`flex size-9 shrink-0 items-center justify-center rounded-lg ${accent ? "bg-[#f8e9e8] text-[#b42318]" : "bg-[#e8eef1] text-[#315f72]"}`}>
          <Icon size={17} strokeWidth={1.8} aria-hidden />
        </span>
      </div>
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

function Series({ title, rows, storageKey, totalLabel = "" }: {
  title: string;
  rows: DayCount[];
  storageKey: string;
  totalLabel?: string;
}) {
  const [days, setDays] = useSessionState<number>(storageKey, 30);
  const countsByDay = new Map(rows.map((row) => [row.day, row.count]));
  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);
  const visibleRows = Array.from({ length: days }, (_, index) => {
    const date = new Date(today);
    date.setUTCDate(date.getUTCDate() - days + index + 1);
    const day = date.toISOString().slice(0, 10);
    return { day, count: countsByDay.get(day) ?? 0 };
  });
  const max = Math.max(1, ...visibleRows.map((r) => r.count));
  return (
    <section className="rounded-[var(--radius)] border border-[var(--border)] bg-white p-4">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <h2 className="text-[14px] font-semibold">{title}</h2>
          {totalLabel ? <span className="text-[12px] text-muted">{sum(visibleRows)} {totalLabel}</span> : null}
        </div>
        <div className="flex rounded-md border border-[#dce2e7] p-0.5">
          {RANGES.map((n) => (
            <Button key={n} type="button" size="sm" variant={days === n ? "default" : "ghost"}
              className="h-7 px-2 text-[11px]" onClick={() => setDays(n)}>{n}д</Button>
          ))}
        </div>
      </div>
      {!visibleRows.length ? (
        <p className="mt-3 text-[13px] text-muted">Нет данных</p>
      ) : (
        <ul className="mt-3 space-y-1.5">
          {visibleRows.map((r) => (
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
  const dash = useQuery({
    queryKey: ["platform-dashboard"],
    queryFn: () => api<Dash>("/api/v1/platform/dashboard"),
  });
  const analytics = useQuery({
    queryKey: ["platform-analytics", 90],
    queryFn: () => api<Analytics>("/api/v1/platform/analytics?days=90"),
    placeholderData: keepPreviousData,
  });

  if (dash.isLoading) return <p className="text-sm text-muted">Загрузка…</p>;
  if (dash.error) return <p className="text-sm text-[var(--danger)]">{(dash.error as Error).message}</p>;
  if (!dash.data) return null;

  const d = dash.data;
  const a = analytics.data;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-[#81909d]">Рабочая область</p>
          <h1 className="mt-1 text-[1.75rem] font-semibold tracking-tight text-[#202938]">Обзор платформы</h1>
          <p className="mt-1 text-[13px] text-[#667485]">Основные показатели и динамика Takt.</p>
        </div>
      </div>

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <Stat
          label="Всего пользователей"
          hint="Зарегистрированные аккаунты"
          value={d.users_total}
          icon={UsersRound}
        />
        <Stat label="Проекты" hint="Все доски на платформе" value={d.projects_total} icon={FolderKanban} />
        <Stat label="Задачи" hint="Неудалённые задачи во всех проектах" value={d.tasks_total} icon={ArrowRight} />
        <Stat
          label="Жалобы и блокировки"
          hint="Открытые жалобы · заблокированные аккаунты"
          value={`${d.open_reports} · ${d.active_blocks}`}
          icon={ShieldAlert}
          accent={Boolean(d.open_reports || d.active_blocks)}
        />
      </div>

      <section className="rounded-xl border border-[#dce2e7] bg-white p-4 sm:p-5">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 className="text-[15px] font-semibold text-[#202938]">Активность пользователей</h2>
            <p className="mt-1 text-[12px] text-[#667485]">Уникальные аккаунты, которые входили за выбранный период.</p>
          </div>
          <div className="flex gap-4 text-[12px]">
            <p className="text-[#667485]">За 24 часа <b className="ml-1 text-[15px] text-[#202938]">{d.dau}</b></p>
            <p className="text-[#667485]">За 7 дней <b className="ml-1 text-[15px] text-[#202938]">{d.wau}</b></p>
            <p className="text-[#667485]">За 30 дней <b className="ml-1 text-[15px] text-[#202938]">{d.mau}</b></p>
          </div>
        </div>
        <div className="mt-4 grid gap-2 border-t border-[#edf0f2] pt-4 sm:grid-cols-2">
          <Link href="/admin/users" className="group flex items-center justify-between rounded-lg bg-[#f4f6f8] px-3 py-3 text-[13px] font-medium text-[#303b49] transition-colors hover:bg-[#e8eef1]">
            <span className="inline-flex items-center gap-2"><UsersRound size={16} className="text-[#315f72]" /> Пользователи</span>
            <ArrowRight size={15} className="text-[#81909d] transition-transform group-hover:translate-x-0.5" />
          </Link>
          <Link href="/admin/projects" className="group flex items-center justify-between rounded-lg bg-[#f4f6f8] px-3 py-3 text-[13px] font-medium text-[#303b49] transition-colors hover:bg-[#e8eef1]">
            <span className="inline-flex items-center gap-2"><FolderKanban size={16} className="text-[#315f72]" /> Проекты и доски</span>
            <ArrowRight size={15} className="text-[#81909d] transition-transform group-hover:translate-x-0.5" />
          </Link>
        </div>
      </section>

      {analytics.isLoading && !a ? (
        <p className="text-sm text-muted">Загружаем динамику…</p>
      ) : a ? (
        <div>
          <div className="mb-3">
            <h2 className="text-[15px] font-semibold text-[#202938]">Динамика по дням</h2>
            <p className="mt-1 text-[12px] text-[#667485]">Для каждого показателя можно отдельно выбрать 7, 30 или 90 дней.</p>
          </div>
          <div className="grid gap-3 lg:grid-cols-2">
          <Series title="Уникальные реальные пользователи, входившие за день" rows={a.active_users} storageKey="takt-admin-active-users-days" />
          <Series title="Регистрации" rows={a.registrations} storageKey="takt-admin-registrations-days" totalLabel="за период" />
          <Series title="Новые проекты" rows={a.projects_created} storageKey="takt-admin-projects-days" totalLabel="за период" />
          <Series title="Созданные задачи" rows={a.tasks_created} storageKey="takt-admin-tasks-days" totalLabel="за период" />
          </div>
        </div>
      ) : null}
    </div>
  );
}

"use client";

import dynamic from "next/dynamic";
import { useQuery } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { api } from "@/lib/api";
import { formatAvgDays, formatOnTimePct } from "@/lib/chart-utils";

const ClosedByDayChart = dynamic(
  () => import("@/components/report-charts").then((m) => m.ClosedByDayChart),
  { ssr: false, loading: () => <p className="text-sm text-muted">Загрузка графика…</p> }
);
const ByStatusChart = dynamic(
  () => import("@/components/report-charts").then((m) => m.ByStatusChart),
  { ssr: false, loading: () => <p className="text-sm text-muted">Загрузка графика…</p> }
);

export default function ReportPage() {
  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ["report"],
    queryFn: () =>
      api<{
        metrics: Record<string, unknown>;
        closed_by_day: { date: string; count: number }[];
        by_employee: Record<string, unknown>[];
        recent_completed: { title: string; closed_at: string }[];
      }>("/api/v1/reports?preset=month"),
    staleTime: 30_000,
  });

  async function download() {
    const res = await fetch("/api/v1/reports/export?preset=month", { credentials: "include" });
    const blob = await res.blob();
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "report.xlsx";
    a.click();
  }

  if (isLoading) return <p className="text-muted">Загрузка отчёта…</p>;
  if (isError || !data) {
    return (
      <div className="surface-card p-6 text-sm text-[var(--danger)]">
        {(error as Error)?.message || "Не удалось загрузить отчёт"}
        <button className="ml-3 font-semibold underline" onClick={() => refetch()}>
          Повторить
        </button>
      </div>
    );
  }

  const m = data.metrics as {
    created: number;
    closed: number;
    in_progress: number;
    overdue: number;
    avg_days: number | null;
    by_status: [string, number][];
  };

  const cards = [
    { label: "Создано", value: String(m.created) },
    { label: "Закрыто", value: String(m.closed) },
    { label: "В работе", value: String(m.in_progress) },
    { label: "Просрочено", value: String(m.overdue) },
    { label: "Среднее время (дн.)", value: formatAvgDays(m.avg_days, m.closed) },
  ];

  const pieData = (m.by_status ?? [])
    .map(([name, value]) => ({ name, value: Number(value) }))
    .filter((d) => d.value > 0);
  const barData = (data.closed_by_day ?? []).map((d) => ({
    day: d.date?.slice(5, 10) ?? "",
    count: d.count,
  }));

  return (
    <div className="max-w-full space-y-6 overflow-x-hidden">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="min-w-0">
          <h1 className="page-title">Отчёты</h1>
          <p className="page-subtitle">Сводка за последний месяц</p>
        </div>
        <Button onClick={download}>Скачать Excel</Button>
      </div>
      <div className="grid grid-cols-2 gap-1.5 sm:grid-cols-3 lg:grid-cols-5 sm:gap-2">
        {cards.map((c) => (
          <div key={c.label} className="surface-panel px-3 py-2.5">
            <div className="section-label">{c.label}</div>
            <div className="mt-0.5 text-xl font-semibold tabular-nums text-foreground">{c.value}</div>
          </div>
        ))}
      </div>
      <div className="grid gap-4 lg:grid-cols-2">
        <div className="surface-panel min-w-0 overflow-hidden p-3 md:p-4">
          <h2 className="mb-2 text-sm font-semibold">Закрыто по дням</h2>
          <div className="w-full">
            <ClosedByDayChart data={barData} />
          </div>
        </div>
        <div className="surface-panel min-w-0 overflow-hidden p-3 md:p-4">
          <h2 className="mb-2 text-sm font-semibold">По статусам</h2>
          <div className="w-full">
            <ByStatusChart data={pieData} />
          </div>
        </div>
      </div>
      <div className="surface-panel overflow-x-auto">
        <table className="min-w-full text-sm">
          <thead className="bg-[var(--surface-2)]">
            <tr>
              {["Сотрудник", "Назначено", "Закрыто", "В работе", "Просрочено", "% в срок"].map((h) => (
                <th key={h} className="px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-muted">
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.by_employee.map((row: Record<string, unknown>) => {
              const pct = row.on_time_pct;
              return (
                <tr key={String(row.user_id)} className="border-t border-hairline">
                  <td className="px-3 py-2.5 font-medium">{String(row.name)}</td>
                  <td className="px-3 py-2.5">{Number(row.assigned)}</td>
                  <td className="px-3 py-2.5">{Number(row.closed)}</td>
                  <td className="px-3 py-2.5">{Number(row.in_progress)}</td>
                  <td className="px-3 py-2.5">{Number(row.overdue)}</td>
                  <td className="px-3 py-2.5">{formatOnTimePct(pct as number | null)}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
      <div className="surface-panel p-3 md:p-4">
        <h2 className="mb-2 text-sm font-semibold">Недавно завершённые</h2>
        <ul className="space-y-1 text-sm">
          {data.recent_completed.map((t, i) => (
            <li key={i} className="flex justify-between gap-3 border-b border-hairline py-2 last:border-0">
              <span>{t.title}</span>
              <span className="shrink-0 text-muted">{t.closed_at?.slice(0, 10)}</span>
            </li>
          ))}
          {!data.recent_completed.length && <li className="text-muted">Пока нет завершённых задач</li>}
        </ul>
      </div>
    </div>
  );
}

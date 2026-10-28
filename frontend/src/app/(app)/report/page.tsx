"use client";

import { useQuery } from "@tanstack/react-query";
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { Button } from "@/components/ui/button";
import { api } from "@/lib/api";

const COLORS = ["#6366f1", "#22c55e", "#f59e0b", "#ef4444", "#8b5cf6"];

export default function ReportPage() {
  const { data, isLoading } = useQuery({
    queryKey: ["report"],
    queryFn: () => api<{ metrics: Record<string, unknown>; closed_by_day: { date: string; count: number }[]; by_employee: Record<string, unknown>[]; recent_completed: { title: string; closed_at: string }[] }>("/api/v1/reports?preset=month"),
  });

  async function download() {
    const res = await fetch("/api/v1/reports/export?preset=month", { credentials: "include" });
    const blob = await res.blob();
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "report.xlsx";
    a.click();
  }

  if (isLoading || !data) return <p className="text-slate-500">Загрузка отчёта…</p>;

  const m = data.metrics as {
    created: number;
    closed: number;
    in_progress: number;
    overdue: number;
    avg_days: number;
    by_status: [string, number][];
    by_priority: Record<string, number>;
  };

  const cards = [
    { label: "Создано", value: m.created },
    { label: "Закрыто", value: m.closed },
    { label: "В работе", value: m.in_progress },
    { label: "Просрочено", value: m.overdue },
    { label: "Среднее время (дн.)", value: m.avg_days },
  ];

  const pieData = m.by_status?.map(([name, value]) => ({ name, value })) ?? [];
  const barData = data.closed_by_day.map((d) => ({
    day: d.date?.slice(0, 10) ?? "",
    count: d.count,
  }));

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h1 className="text-2xl font-semibold">Отчёт</h1>
        <Button onClick={download}>Скачать отчёт в Excel</Button>
      </div>
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
        {cards.map((c) => (
          <div key={c.label} className="rounded-xl border bg-white p-4 shadow-sm dark:border-slate-800 dark:bg-slate-900">
            <div className="text-xs text-slate-500">{c.label}</div>
            <div className="text-2xl font-semibold text-indigo-600">{c.value}</div>
          </div>
        ))}
      </div>
      <div className="grid gap-6 lg:grid-cols-2">
        <div className="h-72 rounded-xl border p-4 dark:border-slate-800">
          <h2 className="mb-2 text-sm font-medium">Закрыто по дням</h2>
          <ResponsiveContainer width="100%" height="90%">
            <BarChart data={barData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="day" hide />
              <YAxis allowDecimals={false} />
              <Tooltip />
              <Bar dataKey="count" fill="#6366f1" />
            </BarChart>
          </ResponsiveContainer>
        </div>
        <div className="h-72 rounded-xl border p-4 dark:border-slate-800">
          <h2 className="mb-2 text-sm font-medium">По статусам</h2>
          <ResponsiveContainer width="100%" height="90%">
            <PieChart>
              <Pie data={pieData} dataKey="value" nameKey="name" outerRadius={90} label>
                {pieData.map((_, i) => (
                  <Cell key={i} fill={COLORS[i % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
        </div>
      </div>
      <div className="overflow-x-auto rounded-xl border dark:border-slate-800">
        <table className="min-w-full text-sm">
          <thead className="bg-slate-100 dark:bg-slate-900">
            <tr>
              {["Сотрудник", "Назначено", "Закрыто", "В работе", "Просрочено", "% в срок"].map((h) => (
                <th key={h} className="px-3 py-2 text-left">
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.by_employee.map((row: Record<string, unknown>) => (
              <tr key={String(row.user_id)} className="border-t dark:border-slate-800">
                <td className="px-3 py-2">{String(row.name)}</td>
                <td className="px-3 py-2">{Number(row.assigned)}</td>
                <td className="px-3 py-2">{Number(row.closed)}</td>
                <td className="px-3 py-2">{Number(row.in_progress)}</td>
                <td className="px-3 py-2">{Number(row.overdue)}</td>
                <td className="px-3 py-2">{Number(row.on_time_pct)}%</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div>
        <h2 className="mb-2 font-medium">Недавно завершённые</h2>
        <ul className="space-y-1 text-sm">
          {data.recent_completed.map((t, i) => (
            <li key={i}>
              {t.title} — {t.closed_at?.slice(0, 10)}
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}

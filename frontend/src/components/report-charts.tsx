"use client";

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
import { padClosedByDay, yAxisMax } from "@/lib/chart-utils";

const COLORS = ["#315F72", "#4A7C59", "#B08D3A", "#A34B45", "#5A7A8C", "#6B7280"];

export function ClosedByDayChart({ data }: { data: { day: string; count: number }[] }) {
  if (!data.length) {
    return <p className="flex h-full items-center justify-center text-sm text-muted">Пока нет закрытых задач</p>;
  }
  const chartData = padClosedByDay(data);
  const maxY = yAxisMax(chartData);
  const single = data.length === 1;

  return (
    <div className="h-full w-full min-h-[220px]">
      <ResponsiveContainer width="100%" height={220} minWidth={0}>
        <BarChart data={chartData} margin={{ top: 8, right: 8, left: 0, bottom: 4 }}>
          <CartesianGrid stroke="var(--border)" strokeDasharray="3 3" vertical={false} />
          <XAxis
            dataKey="day"
            tick={{ fill: "var(--muted-fg)", fontSize: 11 }}
            tickFormatter={(v: string) => (typeof v === "string" ? v.trim() : v)}
          />
          <YAxis
            allowDecimals={false}
            domain={[0, maxY]}
            tick={{ fill: "var(--muted-fg)", fontSize: 11 }}
            width={28}
          />
          <Tooltip
            contentStyle={{
              background: "var(--surface)",
              border: "1px solid var(--border)",
              borderRadius: 12,
              color: "var(--foreground)",
            }}
            formatter={(value) => [Number(value), "Закрыто"]}
            labelFormatter={(label) => (String(label).trim() ? `День: ${label}` : "Нет данных")}
          />
          <Bar
            dataKey="count"
            name="Закрыто"
            fill="var(--accent)"
            radius={[6, 6, 0, 0]}
            maxBarSize={single ? 56 : 40}
          />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}

export function ByStatusChart({ data }: { data: { name: string; value: number }[] }) {
  if (!data.length) {
    return <p className="flex h-full items-center justify-center text-sm text-muted">Нет данных по статусам</p>;
  }
  const total = data.reduce((s, d) => s + d.value, 0);
  // Explicit pixel height: ResponsiveContainer + flex/% height often collapses to 0 → only legend visible.
  const pieSize = 200;

  return (
    <div className="flex h-full flex-col items-stretch gap-3 sm:flex-row sm:items-center">
      <div
        className="mx-auto w-full shrink-0 sm:mx-0"
        style={{ width: "100%", maxWidth: pieSize + 24, height: pieSize }}
        role="img"
        aria-label="Распределение задач по статусам"
      >
        <ResponsiveContainer width="100%" height={pieSize} minWidth={0}>
          <PieChart>
            <Pie
              data={data}
              dataKey="value"
              nameKey="name"
              cx="50%"
              cy="50%"
              innerRadius={48}
              outerRadius={80}
              paddingAngle={2}
              isAnimationActive={false}
              stroke="var(--surface)"
              strokeWidth={2}
            >
              {data.map((_, i) => (
                <Cell key={i} fill={COLORS[i % COLORS.length]} />
              ))}
            </Pie>
            <Tooltip
              contentStyle={{
                background: "var(--surface)",
                border: "1px solid var(--border)",
                borderRadius: 12,
                color: "var(--foreground)",
              }}
              formatter={(value, name) => {
                const n = Number(value);
                const pct = total ? Math.round((n / total) * 100) : 0;
                return [`${n} (${pct}%)`, String(name)];
              }}
            />
          </PieChart>
        </ResponsiveContainer>
      </div>
      <ul className="min-w-0 flex-1 space-y-1.5 px-1 text-sm">
        {data.map((d, i) => {
          const pct = total ? Math.round((d.value / total) * 100) : 0;
          return (
            <li key={d.name} className="flex items-center gap-2">
              <span
                className="h-2.5 w-2.5 shrink-0 rounded-full"
                style={{ background: COLORS[i % COLORS.length] }}
                aria-hidden
              />
              <span className="min-w-0 flex-1 truncate text-foreground">{d.name}</span>
              <span className="tabular-nums text-muted">
                {d.value} · {pct}%
              </span>
            </li>
          );
        })}
      </ul>
    </div>
  );
}

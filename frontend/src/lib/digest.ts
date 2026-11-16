/** Сводка проекта (`GET /api/v1/projects/{id}/digest`). */

export type DigestPeriod = "day" | "week" | "month";

export type DigestTask = {
  task_id: string;
  title: string;
  priority: "low" | "medium" | "high" | "urgent";
  status: string | null;
  assignees: string[];
  due_date: string | null;
  closed_at?: string | null;
  reason?: string | null;
  blocked_by?: string | null;
  days_stuck?: number;
  hours_in_status?: number;
};

export type Digest = {
  project: { id: string; name: string };
  period: { kind: DigestPeriod; start: string; end: string; timezone: string };
  summary: {
    done: number;
    stuck: number;
    overdue: number;
    due_soon: number;
    participation: number | null;
  };
  done: DigestTask[];
  stuck: DigestTask[];
  overdue: DigestTask[];
  due_soon: DigestTask[];
  bottleneck: {
    status_id: string;
    name: string;
    avg_hours: number;
    stays: number;
    tasks: DigestTask[];
  } | null;
  rhythm: {
    enabled: boolean;
    total: number;
    answered: number;
    participation: number | null;
    members_without_answer?: { user_id: string; name: string; total: number; missed: number }[];
  };
  includes_members: boolean;
  viewer: { is_admin: boolean; subscribed: boolean };
  schedule: { daily: boolean; weekly: boolean; time: string };
};

export const PERIODS: { value: DigestPeriod; label: string }[] = [
  { value: "day", label: "День" },
  { value: "week", label: "Неделя" },
  { value: "month", label: "Месяц" },
];

/** 30 → «1 д. 6 ч.», 5.5 → «5 ч.», 0.4 → «< 1 ч.». */
export function formatHours(hours: number): string {
  if (hours < 1) return "< 1 ч.";
  const d = Math.floor(hours / 24);
  const h = Math.round(hours - d * 24);
  if (!d) return `${h} ч.`;
  return h ? `${d} д. ${h} ч.` : `${d} д.`;
}

export function daysLabel(n: number): string {
  if (n <= 0) return "меньше дня";
  const n10 = n % 10;
  const n100 = n % 100;
  if (n100 >= 11 && n100 <= 14) return `${n} дней`;
  if (n10 === 1) return `${n} день`;
  if (n10 >= 2 && n10 <= 4) return `${n} дня`;
  return `${n} дней`;
}

export function participationLabel(p: number | null): string {
  return p === null ? "—" : `${p}%`;
}

/** «12.11 — 18.11» из ISO-дат периода. */
export function periodLabel(period: Digest["period"]): string {
  const fmt = (iso: string) => {
    const [, m, d] = iso.split("-");
    return `${d}.${m}`;
  };
  return period.start === period.end ? fmt(period.end) : `${fmt(period.start)} — ${fmt(period.end)}`;
}

/** Нейтрально, без «пристыживания»: «без ответа: 1 из 5». */
export function missedLabel(m: { missed: number; total: number }): string {
  return `без ответа: ${m.missed} из ${m.total}`;
}

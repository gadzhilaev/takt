/** Ритм: ежедневный чек-ин по своим задачам (API `/api/v1/rhythm/*`). */

export type CheckinAnswer = "done" | "in_progress" | "blocked";

export type CheckinItem = {
  task_id: string;
  title: string;
  priority: "low" | "medium" | "high" | "urgent";
  due_date: string | null;
  status: { id: string; name: string; is_done: boolean } | null;
  blocked_reason: string | null;
  answer: CheckinAnswer | null;
  reason: string | null;
  answered_at: string | null;
};

export type Checkin = {
  id: string;
  project: { id: string; name: string } | null;
  date: string;
  status: "pending" | "answered" | "skipped";
  created_at: string;
  answered_at: string | null;
  items: CheckinItem[];
};

export type CurrentCheckins = { checkins: Checkin[]; pending: number };

export type RhythmSettings = {
  enabled: boolean;
  time: string;
  timezone: string;
  days: number[];
};

export const REASON_MAX = 280;

export const ANSWER_OPTIONS: { value: CheckinAnswer; label: string }[] = [
  { value: "done", label: "Сделал" },
  { value: "in_progress", label: "В работе" },
  { value: "blocked", label: "Застрял" },
];

export type Selection = Record<string, { answer: CheckinAnswer; reason?: string }>;

/** Начальный выбор: уже данные ответы из чек-ина. */
export function initialSelection(checkin: Checkin): Selection {
  const out: Selection = {};
  for (const i of checkin.items) {
    if (i.answer) out[i.task_id] = { answer: i.answer, reason: i.reason ?? undefined };
  }
  return out;
}

/** Тело POST `/answer`: только новые или изменённые ответы. */
export function buildAnswers(checkin: Checkin, selection: Selection) {
  const answers: { task_id: string; answer: CheckinAnswer; reason?: string }[] = [];
  for (const item of checkin.items) {
    const sel = selection[item.task_id];
    if (!sel) continue;
    const reason = sel.answer === "blocked" ? (sel.reason ?? "").trim().slice(0, REASON_MAX) : "";
    const same =
      item.answer === sel.answer && (sel.answer !== "blocked" || (item.reason ?? "") === reason);
    if (same) continue;
    answers.push(
      sel.answer === "blocked" && reason
        ? { task_id: item.task_id, answer: sel.answer, reason }
        : { task_id: item.task_id, answer: sel.answer }
    );
  }
  return answers;
}

export function answeredCount(checkin: Checkin, selection: Selection): number {
  return checkin.items.filter((i) => selection[i.task_id] || i.answer).length;
}

export function tasksWord(n: number): string {
  const n100 = n % 100;
  const n10 = n % 10;
  if (n100 >= 11 && n100 <= 14) return "задач";
  if (n10 === 1) return "задача";
  if (n10 >= 2 && n10 <= 4) return "задачи";
  return "задач";
}

/** Текст баннера на главной. */
export function bannerText(data: CurrentCheckins | undefined): string | null {
  if (!data) return null;
  const pending = data.checkins.filter((c) => c.status === "pending");
  if (!pending.length) return null;
  const left = pending.reduce((n, c) => n + c.items.filter((i) => !i.answer).length, 0);
  if (!left) return null;
  return `Чек-ин на сегодня · ${left} ${tasksWord(left)}`;
}

export const WEEKDAYS: { value: number; short: string }[] = [
  { value: 1, short: "Пн" },
  { value: 2, short: "Вт" },
  { value: 3, short: "Ср" },
  { value: 4, short: "Чт" },
  { value: 5, short: "Пт" },
  { value: 6, short: "Сб" },
  { value: 7, short: "Вс" },
];

export function toggleDay(days: number[], day: number): number[] {
  const uniq = days.filter((d, i) => days.indexOf(d) === i);
  if (uniq.includes(day)) {
    if (uniq.length === 1) return uniq; // хотя бы один день
    return uniq.filter((d) => d !== day).sort((a, b) => a - b);
  }
  return [...uniq, day].sort((a, b) => a - b);
}

/** Часовые пояса России (основные) + текущий, если он не в списке. */
export const RU_TIMEZONES: { value: string; label: string }[] = [
  { value: "Europe/Kaliningrad", label: "Калининград (МСК−1)" },
  { value: "Europe/Moscow", label: "Москва (МСК)" },
  { value: "Europe/Samara", label: "Самара (МСК+1)" },
  { value: "Asia/Yekaterinburg", label: "Екатеринбург (МСК+2)" },
  { value: "Asia/Omsk", label: "Омск (МСК+3)" },
  { value: "Asia/Novosibirsk", label: "Новосибирск (МСК+4)" },
  { value: "Asia/Krasnoyarsk", label: "Красноярск (МСК+4)" },
  { value: "Asia/Irkutsk", label: "Иркутск (МСК+5)" },
  { value: "Asia/Yakutsk", label: "Якутск (МСК+6)" },
  { value: "Asia/Vladivostok", label: "Владивосток (МСК+7)" },
  { value: "Asia/Magadan", label: "Магадан (МСК+8)" },
  { value: "Asia/Kamchatka", label: "Камчатка (МСК+9)" },
];

export function timezoneOptions(current?: string) {
  if (!current || RU_TIMEZONES.some((t) => t.value === current)) return RU_TIMEZONES;
  return [...RU_TIMEZONES, { value: current, label: current }];
}

/** Время чек-ина: шаг 15 минут, 06:00–21:45. */
export const TIME_OPTIONS: { value: string; label: string }[] = (() => {
  const out: { value: string; label: string }[] = [];
  for (let h = 6; h <= 21; h++) {
    for (const m of [0, 15, 30, 45]) {
      const v = `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
      out.push({ value: v, label: v });
    }
  }
  return out;
})();

export function timeOptions(current?: string) {
  if (!current || TIME_OPTIONS.some((t) => t.value === current)) return TIME_OPTIONS;
  return [...TIME_OPTIONS, { value: current, label: current }].sort((a, b) =>
    a.value.localeCompare(b.value)
  );
}

export const DEFAULT_RHYTHM: RhythmSettings = {
  enabled: true,
  time: "10:00",
  timezone: "Europe/Moscow",
  days: [1, 2, 3, 4, 5],
};

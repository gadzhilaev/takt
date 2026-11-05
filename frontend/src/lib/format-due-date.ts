import { formatDurationMs } from "@/lib/time-in-status";

/** Due date chip / form helpers (local timezone). */

export function isDueOverdue(iso: string | null | undefined, now = new Date()): boolean {
  if (!iso) return false;
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return false;
  return d.getTime() < now.getTime();
}

/** Absolute local label for tooltips: «сегодня 18:00», «05.11.2026 14:00». */
export function formatDueAbsolute(iso: string | null | undefined, now = new Date()): string | null {
  if (!iso) return null;
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return null;

  const hh = String(d.getHours()).padStart(2, "0");
  const mm = String(d.getMinutes()).padStart(2, "0");
  const time = `${hh}:${mm}`;

  const startToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const startDay = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const dayDiff = Math.round((startDay.getTime() - startToday.getTime()) / 86_400_000);

  if (dayDiff === 0) return `сегодня ${time}`;
  if (dayDiff === 1) return `завтра ${time}`;
  if (dayDiff === -1) return `вчера ${time}`;

  const dd = String(d.getDate()).padStart(2, "0");
  const mo = String(d.getMonth() + 1).padStart(2, "0");
  if (d.getFullYear() === now.getFullYear()) return `${dd}.${mo} ${time}`;
  return `${dd}.${mo}.${d.getFullYear()} ${time}`;
}

/**
 * Chip like time-in-status: remaining until due («2 ч., 15 мин.»)
 * or overdue duration when past due. Done tasks: absolute date.
 */
export function formatDueChip(
  iso: string | null | undefined,
  now = new Date(),
  opts: { isDone?: boolean } = {}
): string | null {
  if (!iso) return null;
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return null;
  if (opts.isDone) return formatDueAbsolute(iso, now);

  const diff = d.getTime() - now.getTime();
  if (diff >= 0) return formatDurationMs(diff);
  return formatDurationMs(-diff);
}

export function dueChipTitle(
  iso: string | null | undefined,
  now = new Date(),
  opts: { isDone?: boolean } = {}
): string {
  const abs = formatDueAbsolute(iso, now);
  if (opts.isDone) return abs ? `Срок был ${abs}` : "Срок";
  if (isDueOverdue(iso, now)) return abs ? `Просрочено · сдача была ${abs}` : "Срок просрочен";
  return abs ? `До сдачи · ${abs}` : "До сдачи";
}

/** Longer label for drawer. */
export function formatDueLabel(
  iso: string | null | undefined,
  now = new Date(),
  opts: { isDone?: boolean } = {}
): string | null {
  const chip = formatDueChip(iso, now, opts);
  if (!chip) return null;
  if (opts.isDone) return `Срок · ${formatDueAbsolute(iso, now)}`;
  if (isDueOverdue(iso, now)) return `Просрочено · ${chip}`;
  return `До сдачи · ${chip}`;
}

/** Value for `<input type="datetime-local">` from ISO. */
export function toDatetimeLocalValue(iso: string | null | undefined): string {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const yyyy = d.getFullYear();
  const mo = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  const hh = String(d.getHours()).padStart(2, "0");
  const mi = String(d.getMinutes()).padStart(2, "0");
  return `${yyyy}-${mo}-${dd}T${hh}:${mi}`;
}

/** ISO UTC from datetime-local value, or null if empty. */
export function fromDatetimeLocalValue(value: string): string | null {
  const v = value.trim();
  if (!v) return null;
  const d = new Date(v);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString();
}

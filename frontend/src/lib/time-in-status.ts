/** Format a duration in ms as compact Russian label with remainder units. */
export function formatDurationMs(ms: number): string | null {
  if (!Number.isFinite(ms)) return null;
  const safe = Math.max(0, ms);
  const minute = 60_000;
  const hour = 60 * minute;
  const day = 24 * hour;
  const week = 7 * day;

  if (safe < minute) return "сейчас";
  if (safe < hour) {
    const m = Math.floor(safe / minute);
    return `${m} мин.`;
  }
  if (safe < day) {
    const h = Math.floor(safe / hour);
    const remM = Math.floor((safe % hour) / minute);
    if (remM > 0) return `${h} ч., ${remM} мин.`;
    return `${h} ч.`;
  }
  if (safe < week) {
    const d = Math.floor(safe / day);
    const remH = Math.floor((safe % day) / hour);
    if (remH > 0) return `${d} д., ${remH} ч.`;
    return `${d} д.`;
  }
  const w = Math.floor(safe / week);
  const remDays = Math.floor((safe % week) / day);
  if (remDays > 0) return `${w} нед., ${remDays} д.`;
  return `${w} нед.`;
}

/** Human-readable time since task entered its current column (YouGile-style). */
export function formatTimeInStatus(iso: string | null | undefined, now = Date.now()): string | null {
  if (!iso) return null;
  const start = Date.parse(iso);
  if (Number.isNaN(start)) return null;
  return formatDurationMs(now - start);
}

export type TaskTimeFields = {
  created_at?: string | null;
  closed_at?: string | null;
  status_entered_at?: string | null;
  updated_at?: string | null;
};

/**
 * Active task: time in current column (ticks with `now`).
 * Done task: how long solving took (created → closed).
 */
export function formatTaskTimeLabel(
  task: TaskTimeFields,
  opts: { isDone?: boolean; now?: number } = {}
): string | null {
  const now = opts.now ?? Date.now();
  const done = opts.isDone || Boolean(task.closed_at);
  if (done) {
    const startIso = task.created_at;
    const endIso = task.closed_at ?? task.status_entered_at ?? task.updated_at;
    if (!startIso || !endIso) return null;
    const start = Date.parse(startIso);
    const end = Date.parse(endIso);
    if (Number.isNaN(start) || Number.isNaN(end)) return null;
    return formatDurationMs(end - start);
  }
  return formatTimeInStatus(task.status_entered_at ?? task.updated_at ?? task.created_at, now);
}

export function taskTimeTitle(isDone: boolean): string {
  return isDone ? "Сколько заняло решение" : "Сколько задача в этом столбце";
}

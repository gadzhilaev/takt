/** Human-readable time since task entered its current column (YouGile-style). */
export function formatTimeInStatus(iso: string | null | undefined, now = Date.now()): string | null {
  if (!iso) return null;
  const start = Date.parse(iso);
  if (Number.isNaN(start)) return null;
  const ms = Math.max(0, now - start);
  const minute = 60_000;
  const hour = 60 * minute;
  const day = 24 * hour;
  const week = 7 * day;

  if (ms < minute) return "сейчас";
  if (ms < hour) {
    const m = Math.floor(ms / minute);
    return `${m} мин.`;
  }
  if (ms < day) {
    const h = Math.floor(ms / hour);
    return `${h} ч.`;
  }
  if (ms < week) {
    const d = Math.floor(ms / day);
    return `${d} д.`;
  }
  const w = Math.floor(ms / week);
  const remDays = Math.floor((ms % week) / day);
  if (remDays > 0) return `${w} нед., ${remDays} д.`;
  return `${w} нед.`;
}

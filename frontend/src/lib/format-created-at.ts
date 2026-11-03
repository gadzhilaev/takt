/** Relative created-at: сегодня/вчера/дд.мм.гггг в HH:MM (local). */
export function formatCreatedAt(iso: string | null | undefined, now = new Date()): string | null {
  if (!iso) return null;
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return null;

  const hh = String(d.getHours()).padStart(2, "0");
  const mm = String(d.getMinutes()).padStart(2, "0");
  const time = `${hh}:${mm}`;

  const startToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const startDay = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const dayDiff = Math.round((startToday.getTime() - startDay.getTime()) / 86_400_000);

  if (dayDiff === 0) return `сегодня в ${time}`;
  if (dayDiff === 1) return `вчера в ${time}`;

  const dd = String(d.getDate()).padStart(2, "0");
  const mo = String(d.getMonth() + 1).padStart(2, "0");
  return `${dd}.${mo}.${d.getFullYear()} в ${time}`;
}

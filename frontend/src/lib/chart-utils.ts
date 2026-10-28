/** Ensure bar chart with 1–2 points still has readable width and Y scale. */
export function padClosedByDay(data: { day: string; count: number }[]): {
  day: string;
  count: number;
  placeholder?: boolean;
}[] {
  if (!data.length) return [];
  if (data.length >= 3) return data.map((d) => ({ ...d }));
  const placeholders = Math.max(0, 3 - data.length);
  const before = Array.from({ length: Math.floor(placeholders / 2) }, (_, i) => ({
    day: " ",
    count: 0,
    placeholder: true,
    _k: `b${i}`,
  }));
  const after = Array.from({ length: placeholders - before.length }, (_, i) => ({
    day: "  ",
    count: 0,
    placeholder: true,
    _k: `a${i}`,
  }));
  return [...before, ...data.map((d) => ({ ...d, placeholder: false })), ...after];
}

export function yAxisMax(data: { count: number }[]): number {
  const max = data.reduce((m, d) => Math.max(m, d.count), 0);
  return Math.max(max, 1);
}

export function formatAvgDays(value: number | null | undefined, closed: number): string {
  if (!closed || value == null || Number.isNaN(Number(value))) return "—";
  const n = Number(value);
  if (n < 0) return "—";
  if (n < 0.05) return "< 1";
  return String(Math.round(n * 10) / 10);
}

export function formatOnTimePct(value: number | null | undefined): string {
  if (value === null || value === undefined) return "—";
  return `${Number(value)}%`;
}

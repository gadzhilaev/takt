import type { CSSProperties } from "react";

/**
 * Column accent palette. `value` is stored as status.color.
 * Known presets map to solid light/dark surfaces (no stacked translucency).
 */

export type ColumnColorPreset = {
  id: string;
  value: string;
  label: string;
  bg: string;
  border: string;
  bgDark: string;
  borderDark: string;
};

export const COLUMN_COLOR_PALETTE: ColumnColorPreset[] = [
  {
    id: "todo",
    value: "#607FA4",
    label: "К выполнению",
    bg: "#D2DDEB",
    border: "#A8BBD0",
    bgDark: "#2E3A48",
    borderDark: "#4A5F75",
  },
  {
    id: "doing",
    value: "#347FA4",
    label: "В работе",
    bg: "#C9E3F1",
    border: "#7FB5CE",
    bgDark: "#263A45",
    borderDark: "#3A5A6C",
  },
  {
    id: "review",
    value: "#9062B8",
    label: "На проверке",
    bg: "#E0CFF0",
    border: "#B897D0",
    bgDark: "#352A40",
    borderDark: "#584468",
  },
  {
    id: "done",
    value: "#398A62",
    label: "Готово",
    bg: "#CCE8D8",
    border: "#7AB496",
    bgDark: "#2A3C34",
    borderDark: "#3F5C4C",
  },
  {
    id: "slate",
    value: "#7B8794",
    label: "Серый",
    bg: "#E9ECEF",
    border: "#D3D8DE",
    bgDark: "#2E343A",
    borderDark: "#424A52",
  },
  {
    id: "sand",
    value: "#A8895C",
    label: "Песок",
    bg: "#F3EEE4",
    border: "#E2D6C4",
    bgDark: "#353028",
    borderDark: "#4A4236",
  },
];

/** Previous standard accents → current preset id (hex remap only, not by name). */
const LEGACY_ACCENT_ALIASES: Record<string, string> = {
  "#94a3b8": "#607FA4",
  "#7892b2": "#607FA4",
  "#315f72": "#347FA4",
  "#4b8caf": "#347FA4",
  "#5c7380": "#9062B8",
  "#9774bd": "#9062B8",
  "#2f6b4f": "#398A62",
  "#4b9873": "#398A62",
};

const DEFAULT_ACCENT = "#607FA4";

function normalizeHex(color: string): string {
  return color.trim().toLowerCase();
}

export function canonicalizeColumnAccent(color: string): string {
  const key = normalizeHex(color || DEFAULT_ACCENT);
  return LEGACY_ACCENT_ALIASES[key] ?? (color || DEFAULT_ACCENT).trim();
}

export function resolveColumnPreset(color: string): ColumnColorPreset | undefined {
  const key = normalizeHex(canonicalizeColumnAccent(color));
  return COLUMN_COLOR_PALETTE.find((c) => normalizeHex(c.value) === key);
}

/** Derive opaque mixes for custom accents (no translucent stacks). */
function deriveCustom(color: string): Omit<ColumnColorPreset, "id" | "label"> {
  return {
    value: color,
    bg: `color-mix(in srgb, ${color} 28%, #F0F2F5)`,
    border: `color-mix(in srgb, ${color} 42%, #D5DBE3)`,
    bgDark: `color-mix(in srgb, ${color} 28%, #2A3038)`,
    borderDark: `color-mix(in srgb, ${color} 40%, #3F4752)`,
  };
}

export function resolveColumnColors(color: string): Omit<ColumnColorPreset, "id" | "label"> {
  const raw = canonicalizeColumnAccent(color || DEFAULT_ACCENT).trim();
  const preset = resolveColumnPreset(raw);
  if (preset) {
    return {
      value: preset.value,
      bg: preset.bg,
      border: preset.border,
      bgDark: preset.bgDark,
      borderDark: preset.borderDark,
    };
  }
  return deriveCustom(raw);
}

/** Inline CSS vars consumed by `.kanban-column-shell` / accent bar. */
export function columnShellStyle(color: string): CSSProperties {
  const c = resolveColumnColors(color);
  return {
    ["--kanban-col-bg" as string]: c.bg,
    ["--kanban-col-border" as string]: c.border,
    ["--kanban-col-bg-dark" as string]: c.bgDark,
    ["--kanban-col-border-dark" as string]: c.borderDark,
    ["--kanban-col-accent" as string]: c.value,
  };
}

/** @deprecated Prefer columnShellStyle + CSS class. Kept for callers. */
export function softColumnTint(color: string): CSSProperties {
  return columnShellStyle(color);
}

export function columnAccentBar(color: string): CSSProperties {
  const c = resolveColumnColors(color);
  return { backgroundColor: c.value };
}

/** Random vivid accent not already used by current columns. */
export function suggestUnusedColumnColor(used: Array<string | null | undefined>): string {
  const taken = new Set(
    used
      .filter((c): c is string => typeof c === "string" && c.trim().length > 0)
      .map((c) => normalizeHex(c))
  );
  for (const preset of COLUMN_COLOR_PALETTE) {
    if (!taken.has(normalizeHex(preset.value))) return preset.value;
  }
  const extras = ["#C45C4A", "#3D8B7A", "#B06A2B", "#5B6FCF", "#8A5A44", "#2F7D9A"];
  for (const hex of extras) {
    if (!taken.has(normalizeHex(hex))) return hex;
  }
  for (let i = 0; i < 48; i++) {
    const h = Math.floor(Math.random() * 360);
    const s = 42 + Math.floor(Math.random() * 38);
    const l = 38 + Math.floor(Math.random() * 18);
    const hex = hslToHex(h, s, l);
    if (!taken.has(normalizeHex(hex))) return hex;
  }
  return DEFAULT_ACCENT;
}

function hslToHex(h: number, s: number, l: number): string {
  const sat = s / 100;
  const light = l / 100;
  const a = sat * Math.min(light, 1 - light);
  const f = (n: number) => {
    const k = (n + h / 30) % 12;
    const color = light - a * Math.max(Math.min(k - 3, 9 - k, 1), -1);
    return Math.round(255 * color)
      .toString(16)
      .padStart(2, "0");
  };
  return `#${f(0)}${f(8)}${f(4)}`.toUpperCase();
}

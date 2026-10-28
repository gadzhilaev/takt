import type { CSSProperties } from "react";

/** Calm preset palette for Kanban columns (shared via status.color). */

export const COLUMN_COLOR_PALETTE = [
  { id: "slate", value: "#94a3b8", label: "Серый" },
  { id: "brand", value: "#315F72", label: "Сине-серый" },
  { id: "sage", value: "#5C7380", label: "Полынь" },
  { id: "moss", value: "#3D5A4C", label: "Мох" },
  { id: "sand", value: "#6B5E4E", label: "Песок" },
  { id: "clay", value: "#8B6B5B", label: "Глина" },
] as const;

export function softColumnTint(color: string): CSSProperties {
  return {
    backgroundColor: `color-mix(in srgb, ${color} 12%, var(--surface-2))`,
    borderColor: `color-mix(in srgb, ${color} 26%, var(--border))`,
  };
}

export function columnAccentBar(color: string): CSSProperties {
  return {
    backgroundColor: `color-mix(in srgb, ${color} 55%, transparent)`,
  };
}

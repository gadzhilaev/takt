/** Urgency mapped onto Task.priority (medium / high / urgent). */

export type Urgency = "medium" | "high" | "urgent";

export type UrgencyOption = {
  value: Urgency;
  label: string;
  /** Saturated text / stripe color (light theme). */
  color: string;
  /** Soft badge background (light theme). */
  soft: string;
  /** Readable text on dark theme. */
  colorDark: string;
  /** Soft badge background on dark theme. */
  softDark: string;
};

export const URGENCY_OPTIONS: UrgencyOption[] = [
  {
    value: "urgent",
    label: "Срочно",
    color: "#C63F3F",
    soft: "#FCE8E8",
    colorDark: "#E88A8A",
    softDark: "#3A2828",
  },
  {
    value: "high",
    label: "Важно",
    color: "#C47A12",
    soft: "#FFF0D4",
    colorDark: "#D4A45A",
    softDark: "#3A3224",
  },
  {
    value: "medium",
    label: "Обычная",
    color: "#326E8B",
    soft: "#E4F0F6",
    colorDark: "#7AADC4",
    softDark: "#263540",
  },
];

export function urgencyFromPriority(priority: string): Urgency {
  if (priority === "urgent") return "urgent";
  if (priority === "high") return "high";
  return "medium";
}

export function urgencyOption(priority: string): UrgencyOption {
  const u = urgencyFromPriority(priority);
  return URGENCY_OPTIONS.find((o) => o.value === u)!;
}

export function urgencyColor(priority: string): string {
  return urgencyOption(priority).color;
}

export function urgencySoft(priority: string): string {
  return urgencyOption(priority).soft;
}

export function urgencyLabel(priority: string): string {
  return urgencyOption(priority).label;
}

/** CSS variables for stripe + badge (theme-aware via globals.css). */
export function urgencyCssVars(priority: string): Record<string, string> {
  const o = urgencyOption(priority);
  return {
    "--urgency-fg": o.color,
    "--urgency-bg": o.soft,
    "--urgency-fg-dark": o.colorDark,
    "--urgency-bg-dark": o.softDark,
  };
}

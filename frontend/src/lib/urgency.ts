/** Urgency mapped onto Task.priority (medium / high / urgent). */

export type Urgency = "medium" | "high" | "urgent";

export const URGENCY_OPTIONS: { value: Urgency; label: string; color: string }[] = [
  { value: "urgent", label: "Срочно", color: "#C2413B" },
  { value: "high", label: "Важно", color: "#B7791F" },
  { value: "medium", label: "Обычная", color: "#315F72" },
];

export function urgencyFromPriority(priority: string): Urgency {
  if (priority === "urgent") return "urgent";
  if (priority === "high") return "high";
  return "medium";
}

export function urgencyColor(priority: string): string {
  const u = urgencyFromPriority(priority);
  return URGENCY_OPTIONS.find((o) => o.value === u)!.color;
}

export function urgencyLabel(priority: string): string {
  const u = urgencyFromPriority(priority);
  return URGENCY_OPTIONS.find((o) => o.value === u)!.label;
}

import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function getInitials(name: string) {
  return name
    .split(" ")
    .map((p) => p[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();
}

export function priorityLabel(p: string) {
  const map: Record<string, string> = {
    low: "Обычная",
    medium: "Обычная",
    high: "Важно",
    urgent: "Срочно",
  };
  return map[p] ?? p;
}

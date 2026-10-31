"use client";

import { cn } from "@/lib/utils";

export type SortDir = "asc" | "desc";

export function SortableTh({
  label,
  column,
  sort,
  dir,
  onSort,
  className,
}: {
  label: string;
  column: string;
  sort: string;
  dir: SortDir;
  onSort: (column: string) => void;
  className?: string;
}) {
  const active = sort === column;
  return (
    <th className={cn("px-3 py-2 font-medium", className)}>
      <button
        type="button"
        className={cn(
          "inline-flex items-center gap-1 text-left hover:text-foreground",
          active ? "text-foreground" : "text-muted"
        )}
        onClick={() => onSort(column)}
      >
        {label}
        <span className="tabular-nums text-[11px]" aria-hidden>
          {active ? (dir === "asc" ? "↑" : "↓") : "↕"}
        </span>
      </button>
    </th>
  );
}

export function nextSort(current: string, dir: SortDir, column: string): { sort: string; dir: SortDir } {
  if (current === column) {
    return { sort: column, dir: dir === "asc" ? "desc" : "asc" };
  }
  return { sort: column, dir: "asc" };
}

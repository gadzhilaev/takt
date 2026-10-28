"use client";

import { useDroppable } from "@dnd-kit/core";
import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

export function ColumnStartDroppable({
  statusId,
  active,
}: {
  statusId: string;
  active?: boolean;
}) {
  const { setNodeRef } = useDroppable({ id: `col-${statusId}-start` });
  return (
    <div ref={setNodeRef} className="relative h-2 shrink-0">
      {active && (
        <div
          className="pointer-events-none absolute inset-x-0 top-1/2 z-10 h-0.5 -translate-y-1/2 rounded-full bg-[var(--accent)]"
          aria-hidden
        />
      )}
    </div>
  );
}

export function KanbanColumn({
  id,
  children,
  showEmptyIndicator = false,
}: {
  id: string;
  children: ReactNode;
  showEmptyIndicator?: boolean;
}) {
  const { setNodeRef } = useDroppable({ id: `col-${id}` });
  return (
    <div ref={setNodeRef} className="relative w-[17.5rem] shrink-0">
      {showEmptyIndicator && (
        <div
          className="pointer-events-none absolute inset-x-3 top-[5.25rem] z-10 h-0.5 rounded-full bg-[var(--accent)]"
          aria-hidden
        />
      )}
      <div className={cn("h-full min-w-0")}>{children}</div>
    </div>
  );
}

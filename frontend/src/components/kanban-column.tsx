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
    <div ref={setNodeRef} className="relative h-0 shrink-0">
      {active && (
        <div
          className="pointer-events-none absolute inset-x-0 top-0 z-10 h-0.5 rounded-full bg-[var(--accent)]"
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
    <div ref={setNodeRef} className="relative flex w-[17.5rem] shrink-0 flex-col self-start">
      {showEmptyIndicator && (
        <div
          className="pointer-events-none absolute inset-x-3 top-[5.25rem] z-10 h-0.5 rounded-full bg-[var(--accent)]"
          aria-hidden
        />
      )}
      <div className={cn("flex min-w-0 flex-col")}>{children}</div>
    </div>
  );
}

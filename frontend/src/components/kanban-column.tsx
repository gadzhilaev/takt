"use client";

import { useDroppable } from "@dnd-kit/core";
import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

export function KanbanColumn({ id, children }: { id: string; children: ReactNode }) {
  const { setNodeRef, isOver } = useDroppable({ id: `col-${id}` });
  return (
    <div
      ref={setNodeRef}
      className={cn(
        "flex h-full min-w-0 xl:flex-1",
        isOver && "rounded-xl ring-2 ring-[var(--ring)] ring-offset-2 ring-offset-[var(--background)]"
      )}
    >
      {children}
    </div>
  );
}

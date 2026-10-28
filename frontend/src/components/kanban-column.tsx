"use client";

import { useDroppable } from "@dnd-kit/core";
import type { ReactNode } from "react";

export function KanbanColumn({ id, children }: { id: string; children: ReactNode }) {
  const { setNodeRef, isOver } = useDroppable({ id: `col-${id}` });
  return (
    <div ref={setNodeRef} className={isOver ? "ring-2 ring-indigo-400 ring-offset-2 rounded-xl" : ""}>
      {children}
    </div>
  );
}

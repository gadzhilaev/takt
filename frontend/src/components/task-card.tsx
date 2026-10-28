"use client";

import { useDraggable } from "@dnd-kit/core";
import { CSS } from "@dnd-kit/utilities";
import { format, isPast, parseISO } from "date-fns";
import { ru } from "date-fns/locale";
import type { Task } from "@/lib/types";
import { UserAvatar } from "@/components/user-avatar";
import { cn, priorityLabel } from "@/lib/utils";

const priorityColor: Record<string, string> = {
  low: "bg-slate-200 text-slate-700",
  medium: "bg-blue-100 text-blue-800",
  high: "bg-amber-100 text-amber-900",
  urgent: "bg-red-100 text-red-800",
};

export function TaskCard({ task, onOpen }: { task: Task; onOpen: () => void }) {
  const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({ id: task.id });
  const style = transform ? { transform: CSS.Translate.toString(transform) } : undefined;
  const overdue =
    task.due_date && !task.closed_at && isPast(parseISO(task.due_date.endsWith("Z") ? task.due_date : `${task.due_date}Z`));

  return (
    <article
      ref={setNodeRef}
      style={style}
      {...listeners}
      {...attributes}
      className={cn(
        "cursor-grab rounded-lg border border-slate-200 bg-white p-3 shadow-sm active:cursor-grabbing dark:border-slate-700 dark:bg-slate-950",
        isDragging && "opacity-60"
      )}
      onClick={onOpen}
    >
      <div className="mb-2 flex items-start justify-between gap-2">
        <h3 className="text-sm font-medium leading-snug">{task.title}</h3>
        <span className={cn("shrink-0 rounded px-1.5 py-0.5 text-[10px] font-medium", priorityColor[task.priority])}>
          {priorityLabel(task.priority)}
        </span>
      </div>
      {task.due_date && (
        <p className={cn("mb-2 text-xs", overdue ? "font-medium text-red-600" : "text-slate-500")}>
          Срок: {format(parseISO(task.due_date), "d MMM", { locale: ru })}
        </p>
      )}
      <div className="flex flex-wrap gap-1">
        {task.labels.map((l) => (
          <span key={l.id} className="rounded-full px-2 py-0.5 text-[10px] text-white" style={{ background: l.color }}>
            {l.name}
          </span>
        ))}
      </div>
      <div className="mt-2 flex items-center justify-between">
        <div className="flex -space-x-2">
          {task.assignees.slice(0, 3).map((a) => (
            <UserAvatar key={a.id} name={a.name} avatarUrl={a.avatar_url} size={7} />
          ))}
        </div>
        {task.checklist_total > 0 && (
          <span className="text-xs text-slate-500">
            {task.checklist_done}/{task.checklist_total}
          </span>
        )}
      </div>
    </article>
  );
}

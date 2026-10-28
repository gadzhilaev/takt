"use client";

import { useDraggable, useDroppable } from "@dnd-kit/core";
import { CSS } from "@dnd-kit/utilities";
import { format, isPast, parseISO } from "date-fns";
import { ru } from "date-fns/locale";
import { MessageSquare, CheckSquare, GripVertical, Check } from "lucide-react";
import type { Status, Task } from "@/lib/types";
import { UserAvatar } from "@/components/user-avatar";
import { cn, priorityLabel } from "@/lib/utils";

const priorityChip: Record<string, string> = {
  low: "bg-[var(--surface-2)] text-[var(--priority-low)] border border-hairline",
  medium: "bg-[var(--accent-soft)] text-[var(--priority-medium)] border border-transparent",
  high: "bg-[var(--warning-soft)] text-[var(--priority-high)] border border-transparent",
  urgent: "bg-[var(--danger-soft)] text-[var(--priority-urgent)] border border-transparent",
};

export function TaskCard({
  task,
  onOpen,
  onComplete,
  draggable = true,
  statuses,
  onChangeStatus,
}: {
  task: Task;
  onOpen: () => void;
  onComplete?: () => void;
  /** When false, hide drag handle and disable dnd-kit (mobile column mode). */
  draggable?: boolean;
  statuses?: Status[];
  onChangeStatus?: (statusId: string) => void;
}) {
  const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({
    id: task.id,
    disabled: !draggable,
  });
  const { setNodeRef: setDropRef, isOver } = useDroppable({ id: task.id, disabled: !draggable });
  const style = transform ? { transform: CSS.Translate.toString(transform) } : undefined;
  const overdue =
    task.due_date &&
    !task.closed_at &&
    isPast(parseISO(task.due_date.endsWith("Z") ? task.due_date : `${task.due_date}Z`));
  const assignees = task.assignees.slice(0, 3);
  const more = Math.max(0, task.assignees.length - 3);
  const done = !!task.closed_at || !!task.status?.is_done;

  return (
    <article
      ref={(node) => {
        setNodeRef(node);
        setDropRef(node);
      }}
      style={style}
      className={cn(
        "w-full rounded-[var(--radius-lg)] border border-hairline bg-[var(--surface)] p-2",
        isDragging && "opacity-55",
        isOver && "ring-2 ring-[var(--ring)]"
      )}
    >
      <div className="flex gap-0.5">
        {draggable && (
          <button
            type="button"
            className="mt-0.5 flex h-8 w-6 shrink-0 cursor-grab items-center justify-center rounded-[var(--radius-sm)] text-muted hover:bg-[var(--surface-2)] active:cursor-grabbing focus-visible:outline focus-visible:outline-2 focus-visible:outline-[var(--ring)]"
            aria-label={`Переместить задачу «${task.title}»`}
            {...listeners}
            {...attributes}
          >
            <GripVertical className="h-3.5 w-3.5" aria-hidden />
          </button>
        )}
        <div className="min-w-0 flex-1">
          <button
            type="button"
            className="w-full text-left focus-visible:outline focus-visible:outline-2 focus-visible:outline-[var(--ring)]"
            onClick={onOpen}
          >
            <div className="mb-1 flex items-start justify-between gap-2">
              <h3 className="break-words text-[13px] font-semibold leading-snug text-foreground">{task.title}</h3>
              <span className={cn("chip shrink-0", priorityChip[task.priority])}>
                {priorityLabel(task.priority)}
              </span>
            </div>
            {task.due_date && (
              <p className={cn("mb-1 text-[11px] font-medium", overdue ? "text-[var(--danger)]" : "text-muted")}>
                {overdue ? "Просрочено: " : "Срок: "}
                {format(parseISO(task.due_date), "d MMM", { locale: ru })}
              </p>
            )}
          </button>

          {task.labels.length > 0 && (
            <div className="mb-1.5 flex flex-wrap gap-1">
              {task.labels.map((l) => (
                <span
                  key={l.id}
                  className="chip border border-hairline bg-[var(--surface-2)] text-[var(--muted-fg)]"
                >
                  <span className="h-1.5 w-1.5 rounded-full" style={{ background: l.color }} aria-hidden />
                  {l.name}
                </span>
              ))}
            </div>
          )}

          {statuses && onChangeStatus && (
            <div className="mb-2">
              <label className="sr-only" htmlFor={`status-${task.id}`}>
                Статус задачи «{task.title}»
              </label>
              <select
                id={`status-${task.id}`}
                className="field py-1.5 text-sm"
                value={task.status_id}
                onChange={(e) => onChangeStatus(e.target.value)}
                onClick={(e) => e.stopPropagation()}
              >
                {statuses.map((s) => (
                  <option key={s.id} value={s.id}>
                    {s.name}
                  </option>
                ))}
              </select>
            </div>
          )}

          <div className="flex items-center justify-between gap-2">
            <div className="flex min-w-0 items-center gap-2">
              <div className="flex -space-x-1.5">
                {assignees.map((a) => (
                  <UserAvatar key={a.id} name={a.name} avatarUrl={a.avatar_url} size={7} />
                ))}
              </div>
              <span className="truncate text-xs text-muted">
                {assignees.length
                  ? `${assignees.map((a) => a.name.split(" ")[0]).join(", ")}${more ? ` +${more}` : ""}`
                  : "Без исполнителя"}
              </span>
            </div>
            <div className="flex shrink-0 items-center gap-1">
              {task.checklist_total > 0 && (
                <span className="inline-flex items-center gap-0.5 text-xs text-muted" title="Чеклист">
                  <CheckSquare className="h-3.5 w-3.5" aria-hidden />
                  {task.checklist_done}/{task.checklist_total}
                </span>
              )}
              {(task.comment_count ?? 0) > 0 && (
                <span className="inline-flex items-center gap-0.5 text-xs text-muted" title="Комментарии">
                  <MessageSquare className="h-3.5 w-3.5" aria-hidden />
                  {task.comment_count}
                </span>
              )}
              {onComplete && !done && (
                <button
                  type="button"
                  className="inline-flex h-9 w-9 items-center justify-center rounded-lg text-[var(--success)] hover:bg-[var(--success-soft)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-[var(--ring)]"
                  aria-label={`Отметить «${task.title}» выполненной`}
                  title="Готово"
                  onClick={(e) => {
                    e.stopPropagation();
                    onComplete();
                  }}
                >
                  <Check className="h-4 w-4" aria-hidden />
                </button>
              )}
            </div>
          </div>
        </div>
      </div>
    </article>
  );
}

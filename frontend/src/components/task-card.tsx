"use client";

import { useDraggable, useDroppable } from "@dnd-kit/core";
import { Check } from "lucide-react";
import type { Status, Task } from "@/lib/types";
import { UserAvatar } from "@/components/user-avatar";
import { Select } from "@/components/ui/select";
import { Tooltip, TooltipProvider } from "@/components/ui/tooltip";
import { urgencyColor } from "@/lib/urgency";
import { cn } from "@/lib/utils";

export function TaskCard({
  task,
  onOpen,
  draggable = true,
  statuses,
  onChangeStatus,
  isDone = false,
  dropEdge = null,
  overlay = false,
}: {
  task: Task;
  onOpen: () => void;
  draggable?: boolean;
  statuses?: Status[];
  onChangeStatus?: (statusId: string) => void;
  isDone?: boolean;
  dropEdge?: "before" | "after" | null;
  /** Rendered inside DragOverlay — no sensors. */
  overlay?: boolean;
}) {
  const { attributes, listeners, setNodeRef, isDragging } = useDraggable({
    id: task.id,
    disabled: !draggable || overlay,
  });
  const { setNodeRef: setDropRef } = useDroppable({
    id: task.id,
    disabled: !draggable || overlay || isDragging,
  });
  const assignees = task.assignees.slice(0, 4);
  const more = Math.max(0, task.assignees.length - assignees.length);
  const stripe = urgencyColor(task.priority);

  return (
    <div
      className={cn("relative", isDragging && !overlay && "h-0 overflow-hidden opacity-0")}
      aria-hidden={isDragging && !overlay ? true : undefined}
    >
      {!overlay && dropEdge === "before" && (
        <div
          className="pointer-events-none absolute inset-x-0 top-0 z-10 h-0.5 -translate-y-1 rounded-full bg-[var(--accent)]"
          aria-hidden
        />
      )}
      <article
        ref={
          overlay
            ? undefined
            : (node) => {
                setNodeRef(node);
                setDropRef(node);
              }
        }
        className={cn(
          "relative w-full overflow-hidden rounded-[var(--radius)] border border-hairline bg-[var(--surface)]",
          overlay && "shadow-md ring-1 ring-[var(--border)]",
          isDone && !overlay && "opacity-90"
        )}
        {...(draggable && !overlay ? { ...listeners, ...attributes } : {})}
      >
        <span
          className="absolute inset-y-0 left-0 w-[3px]"
          style={{ backgroundColor: stripe }}
          aria-hidden
        />
        <button type="button" className="w-full p-2.5 pl-3.5 text-left" onClick={onOpen}>
          <div className="flex items-start gap-1.5">
            {isDone && (
              <Check
                className="mt-0.5 h-3.5 w-3.5 shrink-0 text-[var(--success)]"
                strokeWidth={2.5}
                aria-label="Выполнено"
              />
            )}
            <h3
              className={cn(
                "min-w-0 flex-1 break-words text-[13px] font-medium leading-snug",
                isDone ? "text-muted" : "text-foreground"
              )}
            >
              {task.title}
            </h3>
          </div>
          {task.description?.trim() && (
            <p
              className={cn(
                "mt-1 line-clamp-2 text-[12px] leading-snug",
                isDone ? "pl-5 text-muted/80" : "text-muted"
              )}
            >
              {task.description}
            </p>
          )}
        </button>

        {assignees.length > 0 && (
          <div className={cn("flex items-center gap-1 px-2.5 pb-2.5 pl-3.5", isDone && "opacity-70")}>
            <TooltipProvider>
              <div className="flex -space-x-1.5">
                {assignees.map((a) => (
                  <Tooltip key={a.id} content={a.name}>
                    <span
                      className="inline-flex rounded-full focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--ring)]"
                      tabIndex={0}
                      aria-label={a.name}
                    >
                      <UserAvatar name={a.name} avatarUrl={a.avatar_url} size={6} title={a.name} />
                    </span>
                  </Tooltip>
                ))}
              </div>
            </TooltipProvider>
            {more > 0 && <span className="text-[11px] text-muted">+{more}</span>}
          </div>
        )}

        {statuses && onChangeStatus && (
          <div className={cn("border-t border-hairline px-2.5 py-2 pl-3.5", isDone && "opacity-75")}>
            <Select
              aria-label={`Столбец «${task.title}»`}
              value={task.status_id}
              onValueChange={onChangeStatus}
              options={statuses.map((s) => ({ value: s.id, label: s.name }))}
            />
          </div>
        )}
      </article>
      {!overlay && dropEdge === "after" && (
        <div
          className="pointer-events-none absolute inset-x-0 bottom-0 z-10 h-0.5 translate-y-1 rounded-full bg-[var(--accent)]"
          aria-hidden
        />
      )}
    </div>
  );
}

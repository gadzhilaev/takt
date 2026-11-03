"use client";

import { AppIcon } from "@/components/ui/app-icon";
import { useDraggable, useDroppable } from "@dnd-kit/core";
import { useLayoutEffect, useRef, useState, type CSSProperties } from "react";
import type { Status, Task } from "@/lib/types";
import { UserAvatar } from "@/components/user-avatar";
import { Select } from "@/components/ui/select";
import { useTickingNow } from "@/hooks/use-ticking-now";
import { formatTaskTimeLabel, taskTimeTitle } from "@/lib/time-in-status";
import { urgencyCssVars, urgencyLabel } from "@/lib/urgency";
import { cn } from "@/lib/utils";

const AVATAR_PX = 28;
const AVATAR_GAP_PX = 4;
const PLUS_RESERVE_PX = 22;

function fitAssigneeCount(width: number, total: number): number {
  if (total <= 0 || width <= 0) return 0;
  const unit = AVATAR_PX + AVATAR_GAP_PX;
  let n = Math.floor((width + AVATAR_GAP_PX) / unit);
  n = Math.max(0, Math.min(total, n));
  if (n >= total) return total;
  n = Math.floor((width - PLUS_RESERVE_PX + AVATAR_GAP_PX) / unit);
  return Math.max(1, Math.min(total - 1, n));
}

function AssigneeAvatars({ assignees }: { assignees: Task["assignees"] }) {
  const ref = useRef<HTMLDivElement>(null);
  const [visible, setVisible] = useState(assignees.length);

  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const update = () => setVisible(fitAssigneeCount(el.clientWidth, assignees.length));
    update();
    const ro = new ResizeObserver(update);
    ro.observe(el);
    return () => ro.disconnect();
  }, [assignees.length]);

  if (!assignees.length) return null;

  const shown = assignees.slice(0, visible);
  const more = assignees.length - shown.length;

  return (
    <div ref={ref} className="flex min-w-0 flex-1 items-center gap-1 overflow-hidden">
      <div className="flex items-center gap-1">
        {shown.map((a) => (
          <UserAvatar key={a.id} name={a.name} avatarUrl={a.avatar_url} size={6} title={a.name} />
        ))}
      </div>
      {more > 0 && (
        <span className="shrink-0 text-[11px] tabular-nums text-[var(--kanban-card-desc)]">+{more}</span>
      )}
    </div>
  );
}

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
  const urgencyVars = urgencyCssVars(task.priority);
  const done = isDone || Boolean(task.closed_at);
  const now = useTickingNow(!done);
  const timeLabel = formatTaskTimeLabel(task, { isDone: done, now });

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
          "kanban-task-card relative w-full overflow-hidden rounded-[var(--radius)]",
          overlay && "kanban-task-card--overlay",
          isDone && "kanban-task-card--done"
        )}
        style={urgencyVars as CSSProperties}
        {...(draggable && !overlay ? { ...listeners, ...attributes } : {})}
      >
        <span className="kanban-task-urgency-stripe" aria-hidden />
        <button type="button" className="w-full p-2.5 pl-3.5 text-left" onClick={onOpen}>
          <div className="flex items-start gap-1.5">
            {isDone && (
              <AppIcon name="check" size={16} className="mt-0.5 shrink-0 text-[var(--success)]" />
            )}
            <h3
              className={cn(
                "min-w-0 flex-1 break-words text-[13px] font-semibold leading-snug",
                isDone ? "text-[var(--kanban-done-title)]" : "text-[var(--kanban-card-title)]"
              )}
            >
              {task.title}
            </h3>
          </div>
          <div className="mt-1.5 flex flex-wrap items-center gap-1.5">
            <span className="kanban-urgency-badge">{urgencyLabel(task.priority)}</span>
            {timeLabel && (
              <span
                className="inline-flex items-center gap-1 rounded-full bg-[var(--surface-2)] px-1.5 py-0.5 text-[11px] font-medium tabular-nums text-muted"
                title={taskTimeTitle(done)}
              >
                <AppIcon name="timer" size={12} className="opacity-70" />
                {timeLabel}
              </span>
            )}
          </div>
          {task.description?.trim() && (
            <p
              className={cn(
                "mt-1.5 line-clamp-2 text-[12px] leading-snug",
                isDone ? "pl-5 text-[var(--kanban-done-desc)]" : "text-[var(--kanban-card-desc)]"
              )}
            >
              {task.description}
            </p>
          )}
        </button>

        {task.assignees.length > 0 && (
          <div className={cn("flex px-2.5 pb-2.5 pl-3.5", isDone && "opacity-85")}>
            <AssigneeAvatars assignees={task.assignees} />
          </div>
        )}

        {statuses && onChangeStatus && (
          <div className={cn("border-t border-hairline px-2.5 py-2 pl-3.5", isDone && "opacity-85")}>
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

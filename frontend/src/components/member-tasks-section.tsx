"use client";

import { AppIcon } from "@/components/ui/app-icon";
import * as SelectPrimitive from "@radix-ui/react-select";
import {
  DndContext,
  DragEndEvent,
  DragOverEvent,
  DragOverlay,
  PointerSensor,
  closestCorners,
  useSensor,
  useSensors,
} from "@dnd-kit/core";
import { useCallback, useEffect, useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { ProjectMember, Status, Task, User } from "@/lib/types";
import { ColumnStartDroppable, KanbanColumn } from "@/components/kanban-column";
import { TaskCard } from "@/components/task-card";
import { UserAvatar } from "@/components/user-avatar";
import { columnShellStyle } from "@/lib/column-colors";
import { isProjectMember, memberTasksTitle, tasksForMember } from "@/lib/member-tasks";
import { cn } from "@/lib/utils";
import { useMediaQuery } from "@/hooks/use-media-query";

function midPosition(before?: number, after?: number) {
  if (before == null && after == null) return 1024;
  if (before == null) {
    const a = after as number;
    return a === 0 ? -1024 : a / 2;
  }
  if (after == null) return before + 1024;
  if (before === after) return before - 1024;
  return (before + after) / 2;
}

function parseColumnDropId(overId: string): { statusId: string; atStart: boolean } | null {
  if (!overId.startsWith("col-")) return null;
  if (overId.endsWith("-start")) {
    return { statusId: overId.slice(4, -6), atStart: true };
  }
  return { statusId: overId.slice(4), atStart: false };
}

type DropIndicator =
  | { kind: "column"; statusId: string }
  | { kind: "start"; statusId: string }
  | { kind: "task"; statusId: string; taskId: string; edge: "before" | "after" };

function MemberSelect({
  members,
  currentUserId,
  value,
  onChange,
}: {
  members: ProjectMember[];
  currentUserId: string;
  value: string;
  onChange: (id: string) => void;
}) {
  const ordered = useMemo(() => {
    const me = members.find((m) => m.user_id === currentUserId);
    const rest = members
      .filter((m) => m.user_id !== currentUserId)
      .slice()
      .sort((a, b) => a.name.localeCompare(b.name, "ru"));
    return me ? [me, ...rest] : rest;
  }, [members, currentUserId]);

  const selected = ordered.find((m) => m.user_id === value);

  return (
    <SelectPrimitive.Root value={value} onValueChange={onChange}>
      <SelectPrimitive.Trigger
        aria-label="Сотрудник"
        className="field flex h-9 max-w-[22rem] items-center justify-between gap-2 px-2.5 text-left text-sm"
      >
        <span className="flex min-w-0 flex-1 items-center gap-2 overflow-hidden">
          {selected && (
            <span className="shrink-0">
              <UserAvatar name={selected.name} avatarUrl={selected.avatar_url} size={6} />
            </span>
          )}
          <span className="min-w-0 flex-1 truncate whitespace-nowrap">
            <SelectPrimitive.Value placeholder="Сотрудник" />
          </span>
        </span>
        <SelectPrimitive.Icon>
          <AppIcon name="chevron-down" size={16} className="shrink-0 opacity-60" />
        </SelectPrimitive.Icon>
      </SelectPrimitive.Trigger>
      <SelectPrimitive.Portal>
        <SelectPrimitive.Content
          position="popper"
          sideOffset={4}
          className="z-[80] max-h-64 min-w-[var(--radix-select-trigger-width)] overflow-hidden rounded-[var(--radius)] border border-hairline bg-[var(--surface)] shadow-sm"
        >
          <SelectPrimitive.Viewport className="p-1">
            {ordered.map((m) => (
              <SelectPrimitive.Item
                key={m.user_id}
                value={m.user_id}
                className="relative flex cursor-pointer select-none items-center gap-2 rounded-[var(--radius-sm)] py-2 pl-8 pr-3 text-sm outline-none data-[highlighted]:bg-[var(--surface-2)]"
              >
                <span className="absolute left-2 flex h-4 w-4 items-center justify-center">
                  <SelectPrimitive.ItemIndicator>
                    <AppIcon name="check" size={16} className="text-[var(--accent)]" />
                  </SelectPrimitive.ItemIndicator>
                </span>
                <UserAvatar name={m.name} avatarUrl={m.avatar_url} size={6} />
                <SelectPrimitive.ItemText className="truncate whitespace-nowrap">
                  {m.user_id === currentUserId ? "Я" : m.name}
                </SelectPrimitive.ItemText>
              </SelectPrimitive.Item>
            ))}
          </SelectPrimitive.Viewport>
        </SelectPrimitive.Content>
      </SelectPrimitive.Portal>
    </SelectPrimitive.Root>
  );
}

export function MemberTasksSection({
  projectId,
  members,
  statuses,
  tasks,
  onOpenTask,
  fillParent = false,
  onMoveTask,
  onHasTasksChange,
}: {
  projectId: string;
  members: ProjectMember[];
  statuses: Status[];
  tasks: Task[];
  onOpenTask: (taskId: string) => void;
  /** Desktop board: occupy parent share when there are tasks. */
  fillParent?: boolean;
  onMoveTask?: (args: { id: string; status_id: string; position: number }) => void;
  /** Сообщает родителю, есть ли задачи у выбранного сотрудника (для split 2/5). */
  onHasTasksChange?: (hasTasks: boolean) => void;
}) {
  const isDesktop = useMediaQuery("(min-width: 768px)");
  const { data: meData } = useQuery({
    queryKey: ["me"],
    queryFn: () => api<{ user: User }>("/api/v1/auth/me"),
    staleTime: 60_000,
  });
  const meId = meData?.user?.id;
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [mobileStatusId, setMobileStatusId] = useState<string | null>(null);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [dropIndicator, setDropIndicator] = useState<DropIndicator | null>(null);

  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 8 } }));
  const canDrag = Boolean(onMoveTask) && isDesktop;

  useEffect(() => {
    setSelectedId(null);
  }, [projectId]);

  useEffect(() => {
    if (!statuses.length) return;
    if (!mobileStatusId || !statuses.some((s) => s.id === mobileStatusId)) {
      setMobileStatusId(statuses[0].id);
    }
  }, [statuses, mobileStatusId]);

  const canShow = !!meId && isProjectMember(members, meId);
  const effectiveId =
    canShow && selectedId && members.some((m) => m.user_id === selectedId) ? selectedId : meId ?? "";
  const filtered = useMemo(
    () => (canShow && effectiveId ? tasksForMember(tasks, effectiveId) : []),
    [canShow, effectiveId, tasks]
  );

  useEffect(() => {
    if (!canShow) {
      onHasTasksChange?.(false);
      return;
    }
    onHasTasksChange?.(filtered.length > 0);
  }, [canShow, filtered.length, onHasTasksChange]);
  const byStatus = useMemo(() => {
    const map: Record<string, Task[]> = {};
    for (const s of statuses) map[s.id] = [];
    for (const t of filtered) {
      if (!map[t.status_id]) map[t.status_id] = [];
      map[t.status_id].push(t);
    }
    for (const id of Object.keys(map)) {
      map[id].sort((a, b) => a.position - b.position);
    }
    return map;
  }, [statuses, filtered]);

  const resolveDrop = useCallback(
    (taskId: string, overId: string): { statusId: string; position: number } | null => {
      if (!filtered.some((t) => t.id === taskId)) return null;

      if (dropIndicator?.kind === "start") {
        const column = [...(byStatus[dropIndicator.statusId] ?? [])].filter((t) => t.id !== taskId);
        return {
          statusId: dropIndicator.statusId,
          position: midPosition(undefined, column[0]?.position),
        };
      }
      if (dropIndicator?.kind === "column") {
        const column = [...(byStatus[dropIndicator.statusId] ?? [])].filter((t) => t.id !== taskId);
        const last = column[column.length - 1];
        return {
          statusId: dropIndicator.statusId,
          position: midPosition(last?.position, undefined),
        };
      }
      if (dropIndicator?.kind === "task") {
        const column = [...(byStatus[dropIndicator.statusId] ?? [])].filter((t) => t.id !== taskId);
        const idx = column.findIndex((t) => t.id === dropIndicator.taskId);
        if (idx < 0) {
          const last = column[column.length - 1];
          return {
            statusId: dropIndicator.statusId,
            position: midPosition(last?.position, undefined),
          };
        }
        if (dropIndicator.edge === "before") {
          const before = idx > 0 ? column[idx - 1]?.position : undefined;
          const after = column[idx]?.position;
          return { statusId: dropIndicator.statusId, position: midPosition(before, after) };
        }
        const before = column[idx]?.position;
        const after = column[idx + 1]?.position;
        return { statusId: dropIndicator.statusId, position: midPosition(before, after) };
      }

      const colDrop = parseColumnDropId(overId);
      if (colDrop) {
        const column = [...(byStatus[colDrop.statusId] ?? [])].filter((t) => t.id !== taskId);
        if (colDrop.atStart) {
          return {
            statusId: colDrop.statusId,
            position: midPosition(undefined, column[0]?.position),
          };
        }
        const last = column[column.length - 1];
        return {
          statusId: colDrop.statusId,
          position: midPosition(last?.position, undefined),
        };
      }

      const overTask = filtered.find((t) => t.id === overId);
      if (!overTask) return null;
      const column = [...(byStatus[overTask.status_id] ?? [])].filter((t) => t.id !== taskId);
      const idx = column.findIndex((t) => t.id === overTask.id);
      const before = idx > 0 ? column[idx - 1]?.position : undefined;
      const after = column[idx]?.position;
      return { statusId: overTask.status_id, position: midPosition(before, after) };
    },
    [byStatus, dropIndicator, filtered]
  );

  const onDragOver = useCallback(
    (event: DragOverEvent) => {
      const { active, over } = event;
      if (!over) {
        setDropIndicator(null);
        return;
      }
      const overId = String(over.id);
      const activeIdStr = String(active.id);
      if (overId === activeIdStr) {
        setDropIndicator(null);
        return;
      }

      const colDrop = parseColumnDropId(overId);
      if (colDrop) {
        if (colDrop.atStart) {
          setDropIndicator({ kind: "start", statusId: colDrop.statusId });
          return;
        }
        const colTasks = (byStatus[colDrop.statusId] ?? []).filter((t) => t.id !== activeIdStr);
        if (!colTasks.length) {
          setDropIndicator({ kind: "column", statusId: colDrop.statusId });
        } else {
          const last = colTasks[colTasks.length - 1];
          setDropIndicator({ kind: "task", statusId: colDrop.statusId, taskId: last.id, edge: "after" });
        }
        return;
      }

      const overTask = filtered.find((t) => t.id === overId);
      if (!overTask) {
        setDropIndicator(null);
        return;
      }

      const activeRect = active.rect.current.translated ?? active.rect.current.initial;
      let edge: "before" | "after" = "before";
      if (activeRect) {
        const activeMidY = activeRect.top + activeRect.height / 2;
        const overMidY = over.rect.top + over.rect.height / 2;
        edge = activeMidY < overMidY ? "before" : "after";
      }

      const colPeers = (byStatus[overTask.status_id] ?? []).filter((t) => t.id !== activeIdStr);
      if (edge === "before" && colPeers[0]?.id === overId) {
        setDropIndicator({ kind: "start", statusId: overTask.status_id });
        return;
      }

      setDropIndicator({ kind: "task", statusId: overTask.status_id, taskId: overId, edge });
    },
    [byStatus, filtered]
  );

  const onDragEnd = useCallback(
    (event: DragEndEvent) => {
      const { active, over } = event;
      const taskId = String(active.id);
      setActiveId(null);

      if (!over || !onMoveTask) {
        setDropIndicator(null);
        return;
      }

      const resolved = resolveDrop(taskId, String(over.id));
      setDropIndicator(null);
      if (!resolved) return;

      const activeTask = filtered.find((t) => t.id === taskId);
      if (!activeTask) return;
      if (
        activeTask.status_id === resolved.statusId &&
        Math.abs(activeTask.position - resolved.position) < 0.0001
      ) {
        return;
      }
      onMoveTask({
        id: taskId,
        status_id: resolved.statusId,
        position: resolved.position,
      });
    },
    [filtered, onMoveTask, resolveDrop]
  );

  function moveToStatus(task: Task, statusId: string) {
    if (!onMoveTask || task.status_id === statusId) return;
    const col = [...(byStatus[statusId] ?? [])].filter((t) => t.id !== task.id);
    const last = col[col.length - 1];
    onMoveTask({
      id: task.id,
      status_id: statusId,
      position: midPosition(last?.position, undefined),
    });
  }

  function taskDropEdge(taskId: string): "before" | "after" | null {
    if (dropIndicator?.kind === "task" && dropIndicator.taskId === taskId) {
      return dropIndicator.edge;
    }
    return null;
  }

  if (!canShow || !meId) return null;

  const title = memberTasksTitle(members, effectiveId, meId);
  const empty = filtered.length === 0;
  const mobileStatus = statuses.find((s) => s.id === mobileStatusId) ?? statuses[0];
  const mobileTasks = mobileStatus ? byStatus[mobileStatus.id] ?? [] : [];
  const selectValue = effectiveId || meId;
  const activeTask = activeId ? filtered.find((t) => t.id === activeId) : null;

  const desktopBoard = (
    <div className="kanban-board-track flex items-start gap-3 overflow-x-auto pb-1">
      {statuses.map((status) => {
        const colTasks = byStatus[status.id] ?? [];
        const emptyDrop =
          dropIndicator?.kind === "column" &&
          dropIndicator.statusId === status.id &&
          colTasks.length === 0;

        const shell = (
          <div
            className="kanban-column-shell flex max-h-[min(28rem,calc(100dvh-16rem))] w-full flex-col overflow-hidden rounded-[var(--radius-lg)] border p-2"
            style={columnShellStyle(status.color || "#607FA4")}
          >
            <div className="kanban-column-accent mb-2 shrink-0" aria-hidden />
            <div className="mb-2 flex shrink-0 items-center gap-1.5 px-1">
              <h3 className="min-w-0 flex-1 truncate text-[13px] font-semibold">{status.name}</h3>
              <span className="text-[11px] tabular-nums text-muted">{colTasks.length}</span>
            </div>
            <div
              className={cn(
                "flex min-h-0 flex-col gap-2 overflow-y-auto",
                colTasks.length === 0 ? "min-h-[2rem]" : null
              )}
            >
              {canDrag && (
                <ColumnStartDroppable
                  statusId={status.id}
                  active={dropIndicator?.kind === "start" && dropIndicator.statusId === status.id}
                />
              )}
              {colTasks.map((task) => (
                <TaskCard
                  key={task.id}
                  task={task}
                  draggable={canDrag}
                  isDone={!!status.is_done}
                  dropEdge={canDrag ? taskDropEdge(task.id) : undefined}
                  onOpen={() => onOpenTask(task.id)}
                />
              ))}
              {!colTasks.length && (
                <p className="py-2 text-center text-[12px] text-muted">Пусто</p>
              )}
            </div>
          </div>
        );

        if (!canDrag) {
          return (
            <div key={status.id} className="kanban-col-width flex shrink-0 flex-col self-start">
              {shell}
            </div>
          );
        }

        return (
          <KanbanColumn key={status.id} id={status.id} showEmptyIndicator={emptyDrop}>
            {shell}
          </KanbanColumn>
        );
      })}
    </div>
  );

  return (
    <section
      className={cn(
        "flex min-h-0 flex-col border-b border-hairline",
        fillParent ? "h-full overflow-hidden pb-2 pt-0" : "shrink-0 pb-2 pt-0"
      )}
      aria-label={title}
    >
      <div className="mb-1.5 flex shrink-0 flex-wrap items-center justify-between gap-2">
        <h2 className="text-sm font-semibold text-foreground">{title}</h2>
        <MemberSelect
          members={members}
          currentUserId={meId}
          value={selectValue}
          onChange={setSelectedId}
        />
      </div>

      {empty ? (
        <p className="rounded-[var(--radius-lg)] border border-dashed border-hairline bg-[var(--surface)] px-3 py-2.5 text-center text-sm text-muted">
          У сотрудника пока нет задач
        </p>
      ) : isDesktop ? (
        canDrag ? (
          <DndContext
            sensors={sensors}
            collisionDetection={closestCorners}
            onDragStart={(e) => setActiveId(String(e.active.id))}
            onDragOver={onDragOver}
            onDragEnd={onDragEnd}
            onDragCancel={() => {
              setActiveId(null);
              setDropIndicator(null);
            }}
          >
            {desktopBoard}
            <DragOverlay dropAnimation={null}>
              {activeTask ? (
                <div className="w-[16.5rem]">
                  <TaskCard
                    task={activeTask}
                    overlay
                    isDone={!!statuses.find((s) => s.id === activeTask.status_id)?.is_done}
                    onOpen={() => {}}
                  />
                </div>
              ) : null}
            </DragOverlay>
          </DndContext>
        ) : (
          desktopBoard
        )
      ) : (
        <div className="space-y-3">
          <div
            className="-mx-1 flex gap-1 overflow-x-auto px-1 pb-1"
            role="tablist"
            aria-label="Столбцы задач сотрудника"
          >
            {statuses.map((status) => {
              const active = status.id === mobileStatus?.id;
              return (
                <button
                  key={status.id}
                  type="button"
                  role="tab"
                  aria-selected={active}
                  className={cn(
                    "min-h-[32px] shrink-0 rounded-full px-2.5 text-[12px] font-medium",
                    active
                      ? "bg-[var(--accent)] text-[var(--accent-fg)]"
                      : "bg-[var(--surface-2)] text-foreground"
                  )}
                  onClick={() => setMobileStatusId(status.id)}
                >
                  {status.name}
                  <span className="ml-1 tabular-nums opacity-70">
                    {(byStatus[status.id] ?? []).length}
                  </span>
                </button>
              );
            })}
          </div>
          {mobileStatus && (
            <div
              className="kanban-column-shell flex flex-col gap-2 rounded-[var(--radius-lg)] border p-2"
              style={columnShellStyle(mobileStatus.color || "#607FA4")}
            >
              {mobileTasks.map((task) => (
                <TaskCard
                  key={task.id}
                  task={task}
                  draggable={false}
                  isDone={!!mobileStatus.is_done}
                  statuses={onMoveTask ? statuses : undefined}
                  onChangeStatus={onMoveTask ? (statusId) => moveToStatus(task, statusId) : undefined}
                  onOpen={() => onOpenTask(task.id)}
                />
              ))}
              {!mobileTasks.length && (
                <p className="py-6 text-center text-sm text-muted">Пусто</p>
              )}
            </div>
          )}
        </div>
      )}
    </section>
  );
}

"use client";

import { AppIcon } from "@/components/ui/app-icon";
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
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useCallback, useEffect, useMemo, useState, type ReactNode } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { api, wsUrl } from "@/lib/api";
import type { ProjectMember, Status, Task } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { MultiSelect } from "@/components/ui/multi-select";
import { Select } from "@/components/ui/select";
import { ColumnStartDroppable, KanbanColumn } from "@/components/kanban-column";
import { TaskCard } from "@/components/task-card";
import { TaskDrawer } from "@/components/task-drawer";
import { MemberTasksSection } from "@/components/member-tasks-section";
import { ErrorState } from "@/components/ui/error-state";
import { EmptyState } from "@/components/ui/empty-state";
import { Skeleton } from "@/components/ui/skeleton";
import { Dialog } from "@/components/ui/dialog";
import { useMediaQuery } from "@/hooks/use-media-query";
import { COLUMN_COLOR_PALETTE, columnShellStyle } from "@/lib/column-colors";
import { URGENCY_OPTIONS, urgencyFromPriority } from "@/lib/urgency";
import { cn } from "@/lib/utils";

function midPosition(before?: number, after?: number) {
  if (before == null && after == null) return 1024;
  if (before == null) {
    const a = after as number;
    // Avoid colliding with position 0 when inserting at the head.
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

type Draft = {
  title: string;
  description: string;
  assigneeIds: string[];
  priority: "medium" | "high" | "urgent";
};

const emptyDraft = (): Draft => ({
  title: "",
  description: "",
  assigneeIds: [],
  priority: "medium",
});

type DropIndicator =
  | { kind: "column"; statusId: string }
  | { kind: "start"; statusId: string }
  | { kind: "task"; statusId: string; taskId: string; edge: "before" | "after" };

export function KanbanBoard({
  projectId,
  members = [],
  startCreate = false,
}: {
  projectId: string;
  members?: ProjectMember[];
  startCreate?: boolean;
}) {
  const qc = useQueryClient();
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const isDesktop = useMediaQuery("(min-width: 768px)");
  const [quickCol, setQuickCol] = useState<string | null>(null);
  const [draft, setDraft] = useState<Draft>(emptyDraft());
  const [activeId, setActiveId] = useState<string | null>(null);
  const [dropIndicator, setDropIndicator] = useState<DropIndicator | null>(null);
  const [mobileStatusId, setMobileStatusId] = useState<string | null>(null);
  const [renamingId, setRenamingId] = useState<string | null>(null);
  const [renameValue, setRenameValue] = useState("");
  const [addingColumn, setAddingColumn] = useState(false);
  const [newColumnName, setNewColumnName] = useState("");
  const [deleteColumn, setDeleteColumn] = useState<Status | null>(null);
  const [moveToStatusId, setMoveToStatusId] = useState("");
  const [mineHasTasks, setMineHasTasks] = useState(false);

  const selectedTaskId = searchParams.get("task");

  const openTask = useCallback(
    (taskId: string) => {
      const next = new URLSearchParams(searchParams.toString());
      next.set("task", taskId);
      next.delete("new");
      next.delete("create");
      router.push(`${pathname}?${next.toString()}`, { scroll: false });
    },
    [pathname, router, searchParams]
  );

  const closeTask = useCallback(() => {
    const next = new URLSearchParams(searchParams.toString());
    next.delete("task");
    const qs = next.toString();
    router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
  }, [pathname, router, searchParams]);

  const statusesQuery = useQuery({
    queryKey: ["statuses", projectId],
    queryFn: () => api<{ items: Status[] }>(`/api/v1/settings/statuses?project_id=${projectId}`),
  });
  const tasksQuery = useQuery({
    queryKey: ["tasks", projectId],
    queryFn: () =>
      api<{ items: Task[] }>(`/api/v1/tasks?project_id=${projectId}&page_size=1000`),
  });

  const statuses = useMemo(() => statusesQuery.data?.items ?? [], [statusesQuery.data?.items]);
  const tasks = useMemo(() => tasksQuery.data?.items ?? [], [tasksQuery.data?.items]);
  const statusById = useMemo(() => {
    const map: Record<string, Status> = {};
    for (const s of statuses) map[s.id] = s;
    return map;
  }, [statuses]);

  const byStatus = useMemo(() => {
    const map: Record<string, Task[]> = {};
    for (const s of statuses) map[s.id] = [];
    for (const t of tasks) {
      if (!map[t.status_id]) map[t.status_id] = [];
      map[t.status_id].push(t);
    }
    for (const id of Object.keys(map)) map[id].sort((a, b) => a.position - b.position);
    return map;
  }, [statuses, tasks]);

  useEffect(() => {
    if (!statuses.length) return;
    if (!mobileStatusId || !statuses.some((s) => s.id === mobileStatusId)) {
      setMobileStatusId(statuses[0].id);
    }
  }, [statuses, mobileStatusId]);

  useEffect(() => {
    if (startCreate && statuses[0] && quickCol == null) setQuickCol(statuses[0].id);
  }, [startCreate, statuses, quickCol]);

  const moveMutation = useMutation({
    mutationFn: ({ id, status_id, position }: { id: string; status_id: string; position: number }) =>
      api(`/api/v1/tasks/${id}/move`, { method: "POST", json: { status_id, position } }),
    onMutate: async ({ id, status_id, position }) => {
      await qc.cancelQueries({ queryKey: ["tasks", projectId] });
      const key = ["tasks", projectId];
      const prev = qc.getQueryData<{ items: Task[] }>(key);
      if (prev) {
        qc.setQueryData(key, {
          items: prev.items.map((t) => (t.id === id ? { ...t, status_id, position } : t)),
        });
      }
      return { prev, key };
    },
    onError: (_e, _v, ctx) => {
      if (ctx?.prev && ctx.key) qc.setQueryData(ctx.key, ctx.prev);
    },
    onSettled: () => qc.invalidateQueries({ queryKey: ["tasks", projectId] }),
  });

  const createMutation = useMutation({
    mutationFn: (payload: {
      title: string;
      status_id: string;
      description?: string | null;
      assignee_ids?: string[];
      priority?: string;
    }) =>
      api("/api/v1/tasks", {
        method: "POST",
        json: { ...payload, project_id: projectId },
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["tasks", projectId] });
      setDraft(emptyDraft());
      setQuickCol(null);
    },
  });

  const columnMutation = useMutation({
    mutationFn: async (action: {
      type: "create" | "rename" | "delete" | "color" | "done";
      id?: string;
      name?: string;
      color?: string;
      is_done?: boolean;
      move_to_status_id?: string;
    }) => {
      if (action.type === "create") {
        return api("/api/v1/settings/statuses", {
          method: "POST",
                  json: { name: action.name, project_id: projectId, color: action.color || "#607FA4" },
        });
      }
      if (action.type === "rename" && action.id) {
        return api(`/api/v1/settings/statuses/${action.id}`, {
          method: "PATCH",
          json: { name: action.name },
        });
      }
      if (action.type === "color" && action.id && action.color) {
        return api(`/api/v1/settings/statuses/${action.id}`, {
          method: "PATCH",
          json: { color: action.color },
        });
      }
      if (action.type === "done" && action.id != null && action.is_done != null) {
        return api(`/api/v1/settings/statuses/${action.id}`, {
          method: "PATCH",
          json: { is_done: action.is_done },
        });
      }
      if (action.type === "delete" && action.id) {
        const qs = action.move_to_status_id
          ? `?move_to_status_id=${action.move_to_status_id}`
          : "";
        return api(`/api/v1/settings/statuses/${action.id}${qs}`, { method: "DELETE" });
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["statuses", projectId] });
      qc.invalidateQueries({ queryKey: ["tasks", projectId] });
      setAddingColumn(false);
      setNewColumnName("");
      setRenamingId(null);
      setDeleteColumn(null);
      setMoveToStatusId("");
    },
  });

  function moveToStatus(task: Task, statusId: string) {
    if (task.status_id === statusId) return;
    const col = [...(byStatus[statusId] ?? [])].filter((t) => t.id !== task.id);
    const last = col[col.length - 1];
    moveMutation.mutate({
      id: task.id,
      status_id: statusId,
      position: midPosition(last?.position, undefined),
    });
  }

  function submitCreate(status: Status) {
    const title = draft.title.trim();
    if (!title) return;
    createMutation.mutate({
      title,
      status_id: status.id,
      description: draft.description.trim() || null,
      assignee_ids: draft.assigneeIds,
      priority: draft.priority,
    });
  }

  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 8 } }));

  const resolveDrop = useCallback(
    (taskId: string, overId: string): { statusId: string; position: number } | null => {
      const activeTask = tasks.find((t) => t.id === taskId);
      if (!activeTask) return null;

      // Prefer live dropIndicator — most accurate for edge/start.
      if (dropIndicator?.kind === "start") {
        const column = [...(byStatus[dropIndicator.statusId] ?? [])].filter((t) => t.id !== taskId);
        const first = column[0];
        return {
          statusId: dropIndicator.statusId,
          position: midPosition(undefined, first?.position),
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

      const overTask = tasks.find((t) => t.id === overId);
      if (!overTask) return null;
      const column = [...(byStatus[overTask.status_id] ?? [])].filter((t) => t.id !== taskId);
      const idx = column.findIndex((t) => t.id === overTask.id);
      const before = idx > 0 ? column[idx - 1]?.position : undefined;
      const after = column[idx]?.position;
      return { statusId: overTask.status_id, position: midPosition(before, after) };
    },
    [byStatus, dropIndicator, tasks]
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

      const overTask = tasks.find((t) => t.id === overId);
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

      // First card "before" ≡ start of column — one indicator, not two.
      const colPeers = (byStatus[overTask.status_id] ?? []).filter((t) => t.id !== activeIdStr);
      if (edge === "before" && colPeers[0]?.id === overId) {
        setDropIndicator({ kind: "start", statusId: overTask.status_id });
        return;
      }

      setDropIndicator({ kind: "task", statusId: overTask.status_id, taskId: overId, edge });
    },
    [byStatus, tasks]
  );

  const onDragEnd = useCallback(
    (event: DragEndEvent) => {
      const { active, over } = event;
      const taskId = String(active.id);
      setActiveId(null);

      if (!over) {
        setDropIndicator(null);
        return;
      }

      const resolved = resolveDrop(taskId, String(over.id));
      setDropIndicator(null);
      if (!resolved) return;

      const activeTask = tasks.find((t) => t.id === taskId);
      if (!activeTask) return;
      if (
        activeTask.status_id === resolved.statusId &&
        Math.abs(activeTask.position - resolved.position) < 0.0001
      ) {
        return;
      }
      moveMutation.mutate({
        id: taskId,
        status_id: resolved.statusId,
        position: resolved.position,
      });
    },
    [moveMutation, resolveDrop, tasks]
  );

  useEffect(() => {
    const url = wsUrl();
    if (!url) return;
    const ws = new WebSocket(url);
    ws.onmessage = () => qc.invalidateQueries({ queryKey: ["tasks", projectId] });
    return () => ws.close();
  }, [qc, projectId]);

  if (statusesQuery.isLoading || tasksQuery.isLoading) {
    return (
      <div className="flex gap-3 overflow-x-auto">
        {[1, 2, 3].map((i) => (
          <Skeleton key={i} className="h-64 w-72 shrink-0 rounded-lg" />
        ))}
      </div>
    );
  }

  if (statusesQuery.isError || tasksQuery.isError) {
    return (
      <ErrorState
        message={
          (statusesQuery.error as Error)?.message ||
          (tasksQuery.error as Error)?.message ||
          ""
        }
        onRetry={() => {
          statusesQuery.refetch();
          tasksQuery.refetch();
        }}
      />
    );
  }

  if (!statuses.length) {
    return (
      <EmptyState
        title="Нет столбцов"
        description="Добавьте первый столбец, чтобы начать"
        action={
          <form
            className="flex gap-2"
            onSubmit={(e) => {
              e.preventDefault();
              if (newColumnName.trim()) {
                columnMutation.mutate({ type: "create", name: newColumnName.trim() });
              }
            }}
          >
            <Input
              value={newColumnName}
              onChange={(e) => setNewColumnName(e.target.value)}
              placeholder="Название столбца"
              autoFocus
            />
            <Button type="submit">Добавить</Button>
          </form>
        }
      />
    );
  }

  const activeTask = activeId ? tasks.find((t) => t.id === activeId) : undefined;
  const mobileStatus = statuses.find((s) => s.id === mobileStatusId) ?? statuses[0];
  const mobileTasks = byStatus[mobileStatus.id] ?? [];

  function taskDropEdge(taskId: string): "before" | "after" | null {
    if (dropIndicator?.kind === "task" && dropIndicator.taskId === taskId) {
      return dropIndicator.edge;
    }
    return null;
  }

  function renderQuickCreate(status: Status) {
    if (quickCol === status.id) {
      return (
        <form
          className="space-y-2 rounded-[var(--radius)] border border-dashed border-hairline bg-[var(--surface)] p-2.5"
          onSubmit={(e) => {
            e.preventDefault();
            submitCreate(status);
          }}
        >
          <label className="label-text" htmlFor={`quick-title-${status.id}`}>
            Название
          </label>
          <Input
            id={`quick-title-${status.id}`}
            autoFocus
            placeholder="Что нужно сделать"
            value={draft.title}
            onChange={(e) => setDraft((d) => ({ ...d, title: e.target.value }))}
            onKeyDown={(e) => {
              if (e.key === "Escape") {
                setQuickCol(null);
                setDraft(emptyDraft());
              }
            }}
          />
          <label className="label-text" htmlFor={`quick-desc-${status.id}`}>
            Описание
          </label>
          <textarea
            id={`quick-desc-${status.id}`}
            className="field min-h-[4.5rem] py-2"
            placeholder="Необязательно"
            value={draft.description}
            onChange={(e) => setDraft((d) => ({ ...d, description: e.target.value }))}
          />
          <label className="label-text" htmlFor={`quick-assignee-${status.id}`}>
            Исполнители
          </label>
          <MultiSelect
            id={`quick-assignee-${status.id}`}
            aria-label="Исполнители"
            values={draft.assigneeIds}
            onChange={(assigneeIds) => setDraft((d) => ({ ...d, assigneeIds }))}
            options={members.map((m) => ({ value: m.user_id, label: m.name }))}
            placeholder="Выберите исполнителей"
            minCount={1}
          />
          <label className="label-text" htmlFor={`quick-urgency-${status.id}`}>
            Срочность
          </label>
          <Select
            id={`quick-urgency-${status.id}`}
            aria-label="Срочность"
            value={draft.priority}
            onValueChange={(priority) =>
              setDraft((d) => ({ ...d, priority: urgencyFromPriority(priority) }))
            }
            options={URGENCY_OPTIONS.map((o) => ({ value: o.value, label: o.label }))}
          />
          <div className="flex gap-2">
            <Button
              type="submit"
              size="sm"
              disabled={
                !draft.title.trim() ||
                draft.assigneeIds.length === 0 ||
                createMutation.isPending
              }
            >
              Создать
            </Button>
            <Button
              type="button"
              size="sm"
              variant="ghost"
              onClick={() => {
                setQuickCol(null);
                setDraft(emptyDraft());
              }}
            >
              Отмена
            </Button>
          </div>
        </form>
      );
    }
    return (
      <button
        type="button"
        className="flex w-full items-center gap-1 rounded-[var(--radius)] px-2 py-1 text-left text-[13px] text-muted hover:bg-[var(--surface)]/60 hover:text-foreground"
        onClick={() => {
          setDraft(emptyDraft());
          setQuickCol(status.id);
        }}
      >
        <AppIcon name="add" size={16} /> Добавить
      </button>
    );
  }

  function columnHeader(status: Status) {
    const count = (byStatus[status.id] ?? []).length;
    if (renamingId === status.id) {
      return (
        <form
          className="flex flex-1 items-center gap-1"
          onSubmit={(e) => {
            e.preventDefault();
            if (renameValue.trim()) {
              columnMutation.mutate({ type: "rename", id: status.id, name: renameValue.trim() });
            }
          }}
        >
          <Input
            className="h-8"
            value={renameValue}
            onChange={(e) => setRenameValue(e.target.value)}
            autoFocus
            onKeyDown={(e) => {
              if (e.key === "Escape") setRenamingId(null);
            }}
          />
          <Button type="submit" size="sm">
            OK
          </Button>
        </form>
      );
    }
    return (
      <>
        <h2 className="min-w-0 flex-1 truncate text-sm font-semibold text-foreground">{status.name}</h2>
        <span className="text-xs tabular-nums text-muted">{count}</span>
        <details className="relative">
          <summary className="flex h-7 w-7 cursor-pointer list-none items-center justify-center rounded text-muted hover:bg-[var(--surface)]/70 hover:text-foreground [&::-webkit-details-marker]:hidden">
            <AppIcon name="more" size={16} />
          </summary>
          <div className="absolute right-0 z-30 mt-1 w-52 rounded-[var(--radius)] border border-hairline bg-[var(--surface)] py-1 shadow-sm">
            <button
              type="button"
              className="block w-full px-3 py-1.5 text-left text-sm hover:bg-[var(--surface-2)]"
              onClick={() => {
                setRenamingId(status.id);
                setRenameValue(status.name);
              }}
            >
              Переименовать
            </button>
            <div className="px-3 py-2">
              <p className="mb-1.5 text-[11px] font-medium uppercase tracking-wide text-muted">Цвет</p>
              <div className="flex flex-wrap gap-1.5">
                {COLUMN_COLOR_PALETTE.map((c) => (
                  <button
                    key={c.id}
                    type="button"
                    title={c.label}
                    aria-label={c.label}
                    className={cn(
                      "h-5 w-5 rounded-full ring-1 ring-[var(--border)]",
                      status.color.toLowerCase() === c.value.toLowerCase() &&
                        "ring-2 ring-[var(--ring)] ring-offset-1 ring-offset-[var(--surface)]"
                    )}
                    style={{ backgroundColor: c.value }}
                    onClick={() => columnMutation.mutate({ type: "color", id: status.id, color: c.value })}
                  />
                ))}
              </div>
            </div>
            <button
              type="button"
              className="flex w-full items-center gap-2 px-3 py-1.5 text-left text-sm hover:bg-[var(--surface-2)]"
              onClick={() =>
                columnMutation.mutate({ type: "done", id: status.id, is_done: !status.is_done })
              }
            >
              <AppIcon name="check" size={20} />
              {status.is_done ? "Снять «завершённый»" : "Столбец завершения"}
            </button>
            <button
              type="button"
              className="block w-full px-3 py-1.5 text-left text-sm text-[var(--danger)] hover:bg-[var(--danger-soft)]"
              onClick={() => {
                setDeleteColumn(status);
                const others = statuses.filter((s) => s.id !== status.id);
                setMoveToStatusId(others[0]?.id ?? "");
              }}
            >
              Удалить
            </button>
          </div>
        </details>
      </>
    );
  }

  function renderColumnShell(status: Status, body: ReactNode, opts?: { fillHeight?: boolean }) {
    const fill = opts?.fillHeight !== false;
    return (
      <div
        className={cn(
          "kanban-column-shell flex w-full flex-col overflow-hidden rounded-[var(--radius-lg)] border p-2",
          fill ? "h-full min-h-0" : "max-h-[min(36rem,calc(100dvh-13rem))]"
        )}
        style={columnShellStyle(status.color || "#607FA4")}
      >
        <div className="kanban-column-accent mb-2 shrink-0" aria-hidden />
        <div className="flex shrink-0 items-center gap-1.5 px-1 pb-1">{columnHeader(status)}</div>
        <div className="mb-0.5 shrink-0 px-0.5">{renderQuickCreate(status)}</div>
        {body}
      </div>
    );
  }

  const drawer = (
    <TaskDrawer
      taskId={selectedTaskId}
      onClose={closeTask}
      statuses={statuses}
      members={members}
    />
  );

  const deleteTaskCount = deleteColumn ? (byStatus[deleteColumn.id] ?? []).length : 0;
  const deleteTargets = deleteColumn
    ? statuses.filter((s) => s.id !== deleteColumn.id)
    : [];

  const deleteColumnDialog = (
    <Dialog
      open={!!deleteColumn}
      onOpenChange={(open) => {
        if (!open) {
          setDeleteColumn(null);
          setMoveToStatusId("");
        }
      }}
      title={deleteColumn ? `Удалить столбец «${deleteColumn.name}»?` : "Удалить столбец"}
    >
      {deleteColumn && (
        <div className="space-y-3">
          {deleteTaskCount > 0 ? (
            <>
              <p className="text-sm text-muted">
                В нём находится {deleteTaskCount}{" "}
                {deleteTaskCount === 1 ? "задача" : deleteTaskCount < 5 ? "задачи" : "задач"}.
              </p>
              <div>
                <label className="label-text" htmlFor="move-tasks-to">
                  Переместить задачи в
                </label>
                <Select
                  id="move-tasks-to"
                  aria-label="Переместить задачи в"
                  value={moveToStatusId}
                  onValueChange={setMoveToStatusId}
                  options={deleteTargets.map((s) => ({ value: s.id, label: s.name }))}
                />
              </div>
            </>
          ) : (
            <p className="text-sm text-muted">Столбец пуст. Подтвердите удаление.</p>
          )}
          {statuses.length <= 1 && (
            <p className="text-sm text-[var(--danger)]">Нельзя удалить последний столбец проекта.</p>
          )}
          <div className="flex justify-end gap-2 pt-1">
            <Button
              type="button"
              size="sm"
              variant="ghost"
              onClick={() => {
                setDeleteColumn(null);
                setMoveToStatusId("");
              }}
            >
              Отмена
            </Button>
            <Button
              type="button"
              size="sm"
              variant="destructive"
              disabled={
                statuses.length <= 1 ||
                columnMutation.isPending ||
                (deleteTaskCount > 0 && !moveToStatusId)
              }
              onClick={() => {
                if (!deleteColumn) return;
                columnMutation.mutate({
                  type: "delete",
                  id: deleteColumn.id,
                  move_to_status_id: deleteTaskCount > 0 ? moveToStatusId : undefined,
                });
              }}
            >
              {deleteTaskCount > 0 ? "Перенести и удалить" : "Удалить"}
            </Button>
          </div>
        </div>
      )}
    </Dialog>
  );

  /* Mobile: one column, vertical scroll */
  if (!isDesktop) {
    return (
      <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto overscroll-contain">
        <MemberTasksSection
          projectId={projectId}
          members={members}
          statuses={statuses}
          tasks={tasks}
          onOpenTask={openTask}
          onMoveTask={(args) => moveMutation.mutate(args)}
        />
        <div className="flex flex-col space-y-3">
          <div className="-mx-1 flex shrink-0 gap-1 overflow-x-auto px-1 pb-1" role="tablist" aria-label="Столбцы">
            {statuses.map((status) => {
              const active = status.id === mobileStatus.id;
              return (
                <button
                  key={status.id}
                  type="button"
                  role="tab"
                  aria-selected={active}
                  className={cn(
                    "min-h-[36px] shrink-0 rounded-full px-3 text-[13px] font-medium",
                    active
                      ? "bg-[var(--accent)] text-[var(--accent-fg)]"
                      : "bg-[var(--surface-2)] text-foreground"
                  )}
                  onClick={() => setMobileStatusId(status.id)}
                >
                  {status.name}
                </button>
              );
            })}
          </div>

          {renderColumnShell(
            mobileStatus,
            <div className={cn("flex flex-col gap-2", !mobileTasks.length && "min-h-[2.5rem]")}>
              {mobileTasks.map((task) => (
                <TaskCard
                  key={task.id}
                  task={task}
                  draggable={false}
                  isDone={!!statusById[task.status_id]?.is_done}
                  statuses={statuses}
                  onChangeStatus={(statusId) => moveToStatus(task, statusId)}
                  onOpen={() => openTask(task.id)}
                />
              ))}
              {!mobileTasks.length && (
                <p className="py-3 text-center text-sm text-muted">Пока пусто</p>
              )}
            </div>,
            { fillHeight: false }
          )}

          {addingColumn ? (
            <form
              className="flex shrink-0 gap-2"
              onSubmit={(e) => {
                e.preventDefault();
                if (newColumnName.trim()) {
                  columnMutation.mutate({ type: "create", name: newColumnName.trim() });
                }
              }}
            >
              <Input
                value={newColumnName}
                onChange={(e) => setNewColumnName(e.target.value)}
                placeholder="Новый столбец"
                autoFocus
              />
              <Button type="submit" size="sm">
                Добавить
              </Button>
              <Button type="button" size="sm" variant="ghost" onClick={() => setAddingColumn(false)}>
                Отмена
              </Button>
            </form>
          ) : (
            <button
              type="button"
              className="shrink-0 text-sm text-muted hover:text-foreground"
              onClick={() => setAddingColumn(true)}
            >
              + Столбец
            </button>
          )}
        </div>
        {drawer}
        {deleteColumnDialog}
      </div>
    );
  }

  /* Desktop: при задачах — 2/5 мои / 3/5 проект; если пусто — блок сжимается */
  return (
    <div className="flex min-h-0 flex-1 flex-col gap-3 overflow-hidden">
      <div
        className={cn(
          "flex min-h-0 flex-col overflow-hidden",
          mineHasTasks ? "flex-[2]" : "shrink-0"
        )}
      >
        <MemberTasksSection
          projectId={projectId}
          members={members}
          statuses={statuses}
          tasks={tasks}
          onOpenTask={openTask}
          fillParent={mineHasTasks}
          onMoveTask={(args) => moveMutation.mutate(args)}
          onHasTasksChange={setMineHasTasks}
        />
      </div>
      <div
        className={cn(
          "flex min-h-0 flex-col overflow-hidden",
          mineHasTasks ? "flex-[3]" : "flex-1"
        )}
      >
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
        <div className="kanban-board-track flex h-full min-h-0 items-stretch gap-3 overflow-x-auto overflow-y-hidden pb-1">
          {statuses.map((status) => {
            const colTasks = byStatus[status.id] ?? [];
            const emptyDrop =
              dropIndicator?.kind === "column" &&
              dropIndicator.statusId === status.id &&
              colTasks.length === 0;
            return (
              <KanbanColumn key={status.id} id={status.id} showEmptyIndicator={emptyDrop}>
                {renderColumnShell(
                  status,
                  <div
                    className={cn(
                      "flex min-h-0 flex-1 flex-col gap-2 overflow-y-auto",
                      colTasks.length === 0 ? "min-h-[2.5rem]" : null
                    )}
                  >
                    <ColumnStartDroppable
                      statusId={status.id}
                      active={dropIndicator?.kind === "start" && dropIndicator.statusId === status.id}
                    />
                    {colTasks.map((task) => (
                      <TaskCard
                        key={task.id}
                        task={task}
                        isDone={!!status.is_done}
                        dropEdge={taskDropEdge(task.id)}
                        onOpen={() => openTask(task.id)}
                      />
                    ))}
                  </div>
                )}
              </KanbanColumn>
            );
          })}

          <div className="kanban-col-width shrink-0 self-start">
            {addingColumn ? (
              <form
                className="space-y-2 rounded-[var(--radius-lg)] bg-[var(--surface-2)]/70 p-2.5"
                onSubmit={(e) => {
                  e.preventDefault();
                  if (newColumnName.trim()) {
                    columnMutation.mutate({ type: "create", name: newColumnName.trim() });
                  }
                }}
              >
                <Input
                  value={newColumnName}
                  onChange={(e) => setNewColumnName(e.target.value)}
                  placeholder="Название столбца"
                  autoFocus
                />
                <div className="flex gap-2">
                  <Button type="submit" size="sm">
                    Добавить
                  </Button>
                  <Button type="button" size="sm" variant="ghost" onClick={() => setAddingColumn(false)}>
                    Отмена
                  </Button>
                </div>
              </form>
            ) : (
              <button
                type="button"
                className="w-full rounded-[var(--radius-lg)] px-3 py-2 text-left text-sm text-muted hover:bg-[var(--surface-2)] hover:text-foreground"
                onClick={() => setAddingColumn(true)}
              >
                + Добавить столбец
              </button>
            )}
          </div>
        </div>
        <DragOverlay dropAnimation={null}>
          {activeTask ? (
            <div className="w-[16.5rem]">
              <TaskCard
                task={activeTask}
                overlay
                isDone={!!statusById[activeTask.status_id]?.is_done}
                onOpen={() => {}}
              />
            </div>
          ) : null}
        </DragOverlay>
      </DndContext>
      </div>
      {drawer}
      {deleteColumnDialog}
    </div>
  );
}

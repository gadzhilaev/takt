"use client";

import {
  DndContext,
  DragEndEvent,
  DragOverlay,
  PointerSensor,
  closestCorners,
  useSensor,
  useSensors,
} from "@dnd-kit/core";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { ChevronLeft, ChevronRight, Plus } from "lucide-react";
import { api, wsUrl } from "@/lib/api";
import type { Status, Task } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { KanbanColumn } from "@/components/kanban-column";
import { TaskCard } from "@/components/task-card";
import { ErrorState } from "@/components/ui/error-state";
import { EmptyState } from "@/components/ui/empty-state";
import { Skeleton } from "@/components/ui/skeleton";
import { useMediaQuery } from "@/hooks/use-media-query";
import { cn } from "@/lib/utils";

function midPosition(before?: number, after?: number) {
  if (before == null && after == null) return 1024;
  if (before == null) return (after as number) / 2;
  if (after == null) return before + 1024;
  return (before + after) / 2;
}

export function KanbanBoard({
  projectId,
  search = "",
  priority,
  assigneeId,
  startCreate = false,
}: {
  projectId: string;
  search?: string;
  priority?: string;
  assigneeId?: string;
  startCreate?: boolean;
}) {
  const qc = useQueryClient();
  const router = useRouter();
  const isDesktop = useMediaQuery("(min-width: 768px)");
  const [quickCol, setQuickCol] = useState<string | null>(null);
  const [quickTitle, setQuickTitle] = useState("");
  const [activeId, setActiveId] = useState<string | null>(null);
  const [mobileStatusId, setMobileStatusId] = useState<string | null>(null);

  const statusesQuery = useQuery({
    queryKey: ["statuses", projectId],
    queryFn: () => api<{ items: Status[] }>(`/api/v1/settings/statuses?project_id=${projectId}`),
  });
  const params = new URLSearchParams({ project_id: projectId, page_size: "1000" });
  if (search) params.set("search", search);
  if (priority) params.set("priority", priority);
  if (assigneeId) params.set("assignee_id", assigneeId);

  const tasksQuery = useQuery({
    queryKey: ["tasks", projectId, search, priority, assigneeId],
    queryFn: () => api<{ items: Task[] }>(`/api/v1/tasks?${params.toString()}`),
  });

  const statuses = useMemo(() => statusesQuery.data?.items ?? [], [statusesQuery.data?.items]);
  const tasks = useMemo(() => tasksQuery.data?.items ?? [], [tasksQuery.data?.items]);

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

  const moveMutation = useMutation({
    mutationFn: ({ id, status_id, position }: { id: string; status_id: string; position: number }) =>
      api(`/api/v1/tasks/${id}/move`, { method: "POST", json: { status_id, position } }),
    onMutate: async ({ id, status_id, position }) => {
      await qc.cancelQueries({ queryKey: ["tasks", projectId] });
      const key = ["tasks", projectId, search, priority, assigneeId];
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
    mutationFn: (payload: { title: string; status_id: string }) =>
      api("/api/v1/tasks", {
        method: "POST",
        json: { ...payload, project_id: projectId, priority: "medium" },
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["tasks", projectId] });
      setQuickTitle("");
      setQuickCol(null);
    },
  });

  const doneStatus = useMemo(() => statuses.find((s) => s.is_done) ?? statuses[statuses.length - 1], [statuses]);

  const completeMutation = useMutation({
    mutationFn: (task: Task) => {
      if (!doneStatus) throw new Error("Нет статуса «Готово»");
      const col = byStatus[doneStatus.id] ?? [];
      const last = col[col.length - 1];
      const position = midPosition(last?.position, undefined);
      return api(`/api/v1/tasks/${task.id}/move`, {
        method: "POST",
        json: { status_id: doneStatus.id, position },
      });
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["tasks", projectId] }),
  });

  function moveToStatus(task: Task, statusId: string) {
    if (task.status_id === statusId) return;
    const col = [...(byStatus[statusId] ?? [])].filter((t) => t.id !== task.id);
    const last = col[col.length - 1];
    const position = midPosition(last?.position, undefined);
    moveMutation.mutate({ id: task.id, status_id: statusId, position });
  }

  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 8 } }));

  const onDragEnd = useCallback(
    (event: DragEndEvent) => {
      setActiveId(null);
      const { active, over } = event;
      if (!over) return;
      const taskId = String(active.id);
      const overId = String(over.id);
      const activeTask = tasks.find((t) => t.id === taskId);
      if (!activeTask) return;

      let statusId = overId.startsWith("col-") ? overId.replace("col-", "") : undefined;
      let overTask: Task | undefined;
      if (!statusId) {
        overTask = tasks.find((t) => t.id === overId);
        statusId = overTask?.status_id;
      }
      if (!statusId) return;

      const column = [...(byStatus[statusId] ?? [])].filter((t) => t.id !== taskId);
      let position: number;
      if (overTask) {
        const idx = column.findIndex((t) => t.id === overTask!.id);
        const before = idx > 0 ? column[idx - 1]?.position : undefined;
        const after = column[idx]?.position;
        position = midPosition(before, after ?? overTask.position);
        if (before == null && after == null) position = midPosition(undefined, overTask.position);
      } else {
        const last = column[column.length - 1];
        position = midPosition(last?.position, undefined);
      }
      if (activeTask.status_id === statusId && Math.abs(activeTask.position - position) < 0.0001) return;
      moveMutation.mutate({ id: taskId, status_id: statusId, position });
    },
    [byStatus, moveMutation, tasks]
  );

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      const tag = (e.target as HTMLElement)?.tagName;
      if (["INPUT", "TEXTAREA", "SELECT"].includes(tag)) return;
      if (e.key.toLowerCase() === "c" && statuses[0]) setQuickCol(statuses[0].id);
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [statuses]);

  useEffect(() => {
    if (startCreate && statuses[0] && quickCol == null) {
      setQuickCol(statuses[0].id);
    }
  }, [startCreate, statuses, quickCol]);

  useEffect(() => {
    const url = wsUrl();
    if (!url) return;
    const ws = new WebSocket(url);
    ws.onmessage = () => qc.invalidateQueries({ queryKey: ["tasks", projectId] });
    return () => ws.close();
  }, [qc, projectId]);

  if (statusesQuery.isLoading || tasksQuery.isLoading) {
    return (
      <div className="flex gap-4 overflow-x-auto">
        {[1, 2, 3, 4].map((i) => (
          <Skeleton key={i} className="h-72 w-full max-w-sm shrink-0 rounded-xl md:w-72" />
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
          "Ошибка загрузки доски"
        }
        onRetry={() => {
          statusesQuery.refetch();
          tasksQuery.refetch();
        }}
      />
    );
  }

  if (!statuses.length) {
    return <EmptyState title="Нет колонок" description="Добавьте статусы в настройках проекта" />;
  }

  const activeTask = activeId ? tasks.find((t) => t.id === activeId) : undefined;
  const mobileIdx = Math.max(
    0,
    statuses.findIndex((s) => s.id === mobileStatusId)
  );
  const mobileStatus = statuses[mobileIdx] ?? statuses[0];
  const mobileTasks = byStatus[mobileStatus.id] ?? [];

  function renderQuickCreate(status: Status) {
    if (quickCol === status.id) {
      return (
        <form
          className="space-y-2 rounded-[var(--radius-lg)] border border-dashed border-hairline bg-[var(--surface-2)] p-2.5"
          onSubmit={(e) => {
            e.preventDefault();
            if (quickTitle.trim()) createMutation.mutate({ title: quickTitle.trim(), status_id: status.id });
          }}
        >
          <label className="label-text" htmlFor={`quick-${status.id}`}>
            Новая задача
          </label>
          <Input
            id={`quick-${status.id}`}
            autoFocus
            placeholder="Например: Подготовить отчёт"
            value={quickTitle}
            onChange={(e) => setQuickTitle(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Escape") {
                setQuickCol(null);
                setQuickTitle("");
              }
            }}
          />
          <div className="flex gap-2">
            <Button type="submit" size="sm" disabled={!quickTitle.trim() || createMutation.isPending}>
              Сохранить
            </Button>
            <Button
              type="button"
              size="sm"
              variant="ghost"
              onClick={() => {
                setQuickCol(null);
                setQuickTitle("");
              }}
            >
              Отмена
            </Button>
          </div>
        </form>
      );
    }
    return (
      <Button variant="secondary" className="w-full justify-start" onClick={() => setQuickCol(status.id)}>
        <Plus className="h-4 w-4" /> Добавить задачу
      </Button>
    );
  }

  /* ——— Mobile: one column + status tabs (no touch DnD) ——— */
  if (!isDesktop) {
    return (
      <div className="space-y-3">
        <div
          className="-mx-1 flex gap-1 overflow-x-auto px-1 pb-1"
          role="tablist"
          aria-label="Статусы доски"
        >
          {statuses.map((status) => {
            const active = status.id === mobileStatus.id;
            const count = (byStatus[status.id] ?? []).length;
            return (
              <button
                key={status.id}
                type="button"
                role="tab"
                aria-selected={active}
                className={cn(
                  "flex min-h-[40px] shrink-0 items-center gap-1.5 rounded-[var(--radius)] px-2.5 text-[13px] font-semibold transition",
                  active
                    ? "bg-[var(--accent)] text-[var(--accent-fg)]"
                    : "border border-hairline bg-[var(--surface)] text-foreground hover:bg-[var(--surface-2)]"
                )}
                onClick={() => setMobileStatusId(status.id)}
              >
                <span
                  className="h-2 w-2 rounded-full"
                  style={{ background: active ? "currentColor" : status.color }}
                  aria-hidden
                />
                {status.name}
                <span
                  className={cn(
                    "rounded-full px-1.5 py-0.5 text-[11px] tabular-nums",
                    active ? "bg-black/15" : "bg-[var(--surface)] text-muted"
                  )}
                >
                  {count}
                </span>
              </button>
            );
          })}
        </div>

        <div className="flex items-center justify-between gap-2">
          <Button
            type="button"
            variant="ghost"
            size="sm"
            disabled={mobileIdx <= 0}
            aria-label="Предыдущий статус"
            onClick={() => setMobileStatusId(statuses[mobileIdx - 1]?.id)}
          >
            <ChevronLeft className="h-4 w-4" /> Назад
          </Button>
          <p className="min-w-0 truncate text-center text-sm font-semibold" style={{ color: mobileStatus.color }}>
            {mobileStatus.name}
          </p>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            disabled={mobileIdx >= statuses.length - 1}
            aria-label="Следующий статус"
            onClick={() => setMobileStatusId(statuses[mobileIdx + 1]?.id)}
          >
            Далее <ChevronRight className="h-4 w-4" />
          </Button>
        </div>

        <p className="text-sm text-muted">
          Смените статус в карточке · {mobileTasks.length}{" "}
          {mobileTasks.length === 1 ? "задача" : mobileTasks.length < 5 ? "задачи" : "задач"}
        </p>

        <div
          className="surface-card flex w-full flex-col gap-2 p-2"
          style={{ borderTopColor: mobileStatus.color, borderTopWidth: 3, borderTopStyle: "solid" }}
        >
          {mobileTasks.map((task) => (
            <TaskCard
              key={task.id}
              task={task}
              draggable={false}
              statuses={statuses}
              onChangeStatus={(statusId) => moveToStatus(task, statusId)}
              onOpen={() => router.push(`/tasks/${task.id}`)}
              onComplete={doneStatus && !mobileStatus.is_done ? () => completeMutation.mutate(task) : undefined}
            />
          ))}
          {!mobileTasks.length && (
            <p className="px-2 py-6 text-center text-sm text-muted">В этом статусе пока нет задач</p>
          )}
          {renderQuickCreate(mobileStatus)}
        </div>
      </div>
    );
  }

  /* ——— Desktop: multi-column + pointer DnD ——— */
  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCorners}
      onDragStart={(e) => setActiveId(String(e.active.id))}
      onDragEnd={onDragEnd}
      onDragCancel={() => setActiveId(null)}
    >
      <div className="flex gap-3 overflow-x-auto pb-4 xl:gap-4 2xl:overflow-visible">
        {statuses.map((status) => (
          <KanbanColumn key={status.id} id={status.id}>
            <div className="flex h-full w-[19rem] shrink-0 flex-col surface-card lg:w-72 lg:min-w-[16rem] xl:min-w-0 xl:max-w-none xl:flex-1 xl:shrink">
              <div
                className="flex items-center justify-between border-b border-hairline px-3 py-2.5"
                style={{ borderTopColor: status.color, borderTopWidth: 2, borderTopStyle: "solid" }}
              >
                <h2 className="text-sm font-semibold">{status.name}</h2>
                <span className="rounded-full bg-[var(--surface-2)] px-2 py-0.5 text-xs font-medium text-muted">
                  {(byStatus[status.id] ?? []).length}
                </span>
              </div>
              <div className="flex max-h-[min(68vh,34rem)] flex-1 flex-col gap-2 overflow-y-auto overscroll-contain p-2">
                {(byStatus[status.id] ?? []).map((task) => (
                  <TaskCard
                    key={task.id}
                    task={task}
                    onOpen={() => router.push(`/tasks/${task.id}`)}
                    onComplete={doneStatus && !status.is_done ? () => completeMutation.mutate(task) : undefined}
                  />
                ))}
                {renderQuickCreate(status)}
              </div>
            </div>
          </KanbanColumn>
        ))}
      </div>
      <DragOverlay>{activeTask ? <TaskCard task={activeTask} onOpen={() => {}} /> : null}</DragOverlay>
    </DndContext>
  );
}

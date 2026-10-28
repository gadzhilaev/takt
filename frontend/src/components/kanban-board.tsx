"use client";

import {
  DndContext,
  DragEndEvent,
  PointerSensor,
  TouchSensor,
  useSensor,
  useSensors,
} from "@dnd-kit/core";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Plus } from "lucide-react";
import { api, wsUrl } from "@/lib/api";
import type { Status, Task } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { KanbanColumn } from "@/components/kanban-column";
import { TaskCard } from "@/components/task-card";
import { TaskDrawer } from "@/components/task-drawer";

export function KanbanBoard() {
  const qc = useQueryClient();
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [quickCol, setQuickCol] = useState<string | null>(null);
  const [quickTitle, setQuickTitle] = useState("");

  const { data: statusesData } = useQuery({
    queryKey: ["statuses"],
    queryFn: () => api<{ items: Status[] }>("/api/v1/settings/statuses"),
  });
  const { data: tasksData } = useQuery({
    queryKey: ["tasks"],
    queryFn: () => api<{ items: Task[] }>("/api/v1/tasks?page_size=1000"),
  });

  const statuses = statusesData?.items ?? [];
  const tasks = tasksData?.items ?? [];

  const byStatus = useMemo(() => {
    const map: Record<string, Task[]> = {};
    for (const s of statuses) map[s.id] = [];
    for (const t of tasks) {
      if (!map[t.status_id]) map[t.status_id] = [];
      map[t.status_id].push(t);
    }
    for (const id of Object.keys(map)) {
      map[id].sort((a, b) => a.position - b.position);
    }
    return map;
  }, [statuses, tasks]);

  const moveMutation = useMutation({
    mutationFn: ({ id, status_id, position }: { id: string; status_id: string; position: number }) =>
      api(`/api/v1/tasks/${id}/move`, { method: "POST", json: { status_id, position } }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["tasks"] }),
  });

  const createMutation = useMutation({
    mutationFn: (payload: { title: string; status_id: string }) =>
      api("/api/v1/tasks", { method: "POST", json: { ...payload, priority: "medium" } }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["tasks"] });
      setQuickTitle("");
      setQuickCol(null);
    },
  });

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 8 } }),
    useSensor(TouchSensor, { activationConstraint: { delay: 250, tolerance: 8 } })
  );

  const onDragEnd = useCallback(
    (event: DragEndEvent) => {
      const { active, over } = event;
      if (!over) return;
      const taskId = String(active.id);
      const overId = String(over.id);
      const statusId = overId.startsWith("col-") ? overId.replace("col-", "") : undefined;
      if (!statusId) return;
      const column = byStatus[statusId] ?? [];
      const position = (column[column.length - 1]?.position ?? 0) + 1024;
      moveMutation.mutate({ id: taskId, status_id: statusId, position });
    },
    [byStatus, moveMutation]
  );

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key.toLowerCase() === "c" && !(e.target instanceof HTMLInputElement)) {
        if (statuses[0]) setQuickCol(statuses[0].id);
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [statuses]);

  useEffect(() => {
    const url = wsUrl();
    if (!url) return;
    const ws = new WebSocket(url);
    ws.onmessage = () => qc.invalidateQueries({ queryKey: ["tasks"] });
    return () => ws.close();
  }, [qc]);

  return (
    <>
      <DndContext sensors={sensors} onDragEnd={onDragEnd}>
        <div className="flex gap-4 overflow-x-auto pb-4 snap-x snap-mandatory">
          {statuses.map((status) => (
            <KanbanColumn key={status.id} id={status.id}>
            <div
              className="w-[min(100%,20rem)] shrink-0 snap-center rounded-xl border border-slate-200 bg-white shadow-sm dark:border-slate-800 dark:bg-slate-900"
            >
              <div
                className="flex items-center justify-between border-b px-3 py-3 dark:border-slate-800"
                style={{ borderTopColor: status.color, borderTopWidth: 3 }}
              >
                <h2 className="text-sm font-semibold">{status.name}</h2>
                <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs dark:bg-slate-800">
                  {(byStatus[status.id] ?? []).length}
                </span>
              </div>
              <div className="flex max-h-[70vh] flex-col gap-2 overflow-y-auto p-2">
                {(byStatus[status.id] ?? []).map((task) => (
                  <TaskCard key={task.id} task={task} onOpen={() => setSelectedId(task.id)} />
                ))}
                {quickCol === status.id ? (
                  <form
                    className="space-y-2 rounded-lg border border-dashed p-2"
                    onSubmit={(e) => {
                      e.preventDefault();
                      if (quickTitle.trim())
                        createMutation.mutate({ title: quickTitle.trim(), status_id: status.id });
                    }}
                  >
                    <Input
                      autoFocus
                      placeholder="Название задачи"
                      value={quickTitle}
                      onChange={(e) => setQuickTitle(e.target.value)}
                    />
                  </form>
                ) : (
                  <Button
                    variant="ghost"
                    className="w-full justify-start text-slate-500"
                    onClick={() => setQuickCol(status.id)}
                  >
                    <Plus className="h-4 w-4" /> Добавить
                  </Button>
                )}
              </div>
            </div>
            </KanbanColumn>
          ))}
        </div>
      </DndContext>
      <TaskDrawer taskId={selectedId} onClose={() => setSelectedId(null)} statuses={statuses} />
    </>
  );
}

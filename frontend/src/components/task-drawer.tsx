"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { X } from "lucide-react";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import type { Status, Task } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { priorityLabel } from "@/lib/utils";

export function TaskDrawer({
  taskId,
  onClose,
  statuses,
}: {
  taskId: string | null;
  onClose: () => void;
  statuses: Status[];
}) {
  const qc = useQueryClient();
  const { data } = useQuery({
    queryKey: ["task", taskId],
    enabled: !!taskId,
    queryFn: () => api<{ task: Task }>(`/api/v1/tasks/${taskId}`),
  });
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");

  useEffect(() => {
    if (data?.task) {
      setTitle(data.task.title);
      setDescription(data.task.description ?? "");
    }
  }, [data?.task]);

  const patch = useMutation({
    mutationFn: (json: Record<string, unknown>) =>
      api(`/api/v1/tasks/${taskId}`, { method: "PATCH", json }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["tasks"] });
      qc.invalidateQueries({ queryKey: ["task", taskId] });
    },
  });

  useEffect(() => {
    if (!taskId || !data?.task) return;
    const t = setTimeout(() => {
      if (title !== data.task.title) patch.mutate({ title });
    }, 600);
    return () => clearTimeout(t);
  }, [title, taskId, data?.task, patch]);

  if (!taskId) return null;
  const task = data?.task;

  return (
    <div className="fixed inset-0 z-50 flex justify-end bg-black/40" role="dialog" aria-modal="true" aria-label="Редактирование задачи">
      <div className="h-full w-full max-w-lg overflow-y-auto bg-[var(--surface)] p-4 shadow-soft md:rounded-l-xl">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-semibold">Задача</h2>
          <Button variant="ghost" size="icon" aria-label="Закрыть" onClick={onClose}>
            <X className="h-5 w-5" />
          </Button>
        </div>
        {task ? (
          <div className="space-y-4">
            <div>
              <label className="label-text" htmlFor="drawer-title">
                Название
              </label>
              <Input id="drawer-title" value={title} onChange={(e) => setTitle(e.target.value)} />
            </div>
            <div>
              <label className="label-text" htmlFor="drawer-desc">
                Описание
              </label>
              <textarea
                id="drawer-desc"
                className="field min-h-[120px] resize-y"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                onBlur={() => patch.mutate({ description })}
                placeholder="Кратко опишите, что нужно сделать…"
              />
            </div>
            <div>
              <label className="label-text" htmlFor="drawer-status">
                Статус
              </label>
              <select
                id="drawer-status"
                className="field"
                value={task.status_id}
                onChange={(e) => patch.mutate({ status_id: e.target.value })}
              >
                {statuses.map((s) => (
                  <option key={s.id} value={s.id}>
                    {s.name}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="label-text" htmlFor="drawer-priority">
                Важность
              </label>
              <select
                id="drawer-priority"
                className="field"
                value={task.priority}
                onChange={(e) => patch.mutate({ priority: e.target.value })}
              >
                {(["low", "medium", "high", "urgent"] as const).map((p) => (
                  <option key={p} value={p}>
                    {priorityLabel(p)}
                  </option>
                ))}
              </select>
            </div>
          </div>
        ) : (
          <p className="text-sm text-muted">Загрузка…</p>
        )}
      </div>
    </div>
  );
}

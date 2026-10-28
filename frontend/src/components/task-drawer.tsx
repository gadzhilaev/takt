"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Trash2, X } from "lucide-react";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import type { ProjectMember, Status, Task, User } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { MultiSelect } from "@/components/ui/multi-select";
import { URGENCY_OPTIONS, urgencyFromPriority } from "@/lib/urgency";
import { cn } from "@/lib/utils";

export function TaskDrawer({
  taskId,
  onClose,
  statuses,
  members = [],
}: {
  taskId: string | null;
  onClose: () => void;
  statuses: Status[];
  members?: ProjectMember[];
}) {
  const qc = useQueryClient();
  const { data: meData } = useQuery({
    queryKey: ["me"],
    queryFn: () => api<{ user: User }>("/api/v1/auth/me"),
  });
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

  useEffect(() => {
    if (!taskId) return;
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [taskId, onClose]);

  const patch = useMutation({
    mutationFn: (json: Record<string, unknown>) =>
      api(`/api/v1/tasks/${taskId}`, { method: "PATCH", json }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["tasks"] });
      qc.invalidateQueries({ queryKey: ["task", taskId] });
    },
  });

  const remove = useMutation({
    mutationFn: () => api(`/api/v1/tasks/${taskId}`, { method: "DELETE" }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["tasks"] });
      onClose();
    },
  });

  useEffect(() => {
    if (!taskId || !data?.task) return;
    const t = setTimeout(() => {
      if (title.trim() && title !== data.task.title) {
        patch.mutate({ title: title.trim() });
      }
    }, 600);
    return () => clearTimeout(t);
  }, [title, taskId, data?.task, patch]);

  if (!taskId) return null;
  const task = data?.task;
  const assigneeIds = task?.assignees.map((a) => a.id) ?? [];
  const isAuthor = !!task && !!meData?.user && task.author_id === meData.user.id;

  return (
    <div className="fixed inset-0 z-50 flex justify-end" role="dialog" aria-modal="true" aria-label="Задача">
      <button type="button" className="absolute inset-0 bg-black/25" aria-label="Закрыть" onClick={onClose} />
      <aside
        className={cn(
          "relative z-10 flex h-full w-full flex-col border-l border-hairline bg-[var(--surface)] shadow-sm",
          "md:w-[480px] md:max-w-[520px]"
        )}
      >
        <div className="flex items-center justify-between border-b border-hairline px-4 py-3">
          <h2 className="text-base font-semibold">Задача</h2>
          <Button variant="ghost" size="icon" aria-label="Закрыть" onClick={onClose}>
            <X className="h-5 w-5" />
          </Button>
        </div>

        <div className="flex-1 space-y-4 overflow-y-auto p-4">
          {task ? (
            <>
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
                  className="field min-h-[7rem] resize-y py-2"
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  onBlur={() => {
                    if ((task.description ?? "") !== description) {
                      patch.mutate({ description });
                    }
                  }}
                  placeholder="Необязательно"
                />
              </div>
              <div>
                <label className="label-text" htmlFor="drawer-assignees">
                  Исполнители
                </label>
                <MultiSelect
                  id="drawer-assignees"
                  aria-label="Исполнители"
                  values={assigneeIds}
                  onChange={(ids) => patch.mutate({ assignee_ids: ids })}
                  options={members.map((m) => ({ value: m.user_id, label: m.name }))}
                  placeholder="Не назначены"
                />
              </div>
              <div>
                <label className="label-text" htmlFor="drawer-status">
                  Столбец
                </label>
                <Select
                  id="drawer-status"
                  aria-label="Столбец"
                  value={task.status_id}
                  onValueChange={(status_id) => patch.mutate({ status_id })}
                  options={statuses.map((s) => ({ value: s.id, label: s.name }))}
                />
              </div>
              <div>
                <label className="label-text" htmlFor="drawer-urgency">
                  Срочность
                </label>
                <Select
                  id="drawer-urgency"
                  aria-label="Срочность"
                  value={urgencyFromPriority(task.priority)}
                  onValueChange={(priority) => patch.mutate({ priority })}
                  options={URGENCY_OPTIONS.map((o) => ({ value: o.value, label: o.label }))}
                />
              </div>
              {patch.isPending && <p className="text-xs text-muted">Сохранение…</p>}
              {isAuthor && (
                <div className="border-t border-hairline pt-4">
                  <Button
                    type="button"
                    variant="ghost"
                    className="text-[var(--danger)] hover:bg-[var(--danger-soft)] hover:text-[var(--danger)]"
                    disabled={remove.isPending}
                    onClick={() => {
                      if (confirm("Удалить задачу?")) remove.mutate();
                    }}
                  >
                    <Trash2 className="h-4 w-4" /> Удалить задачу
                  </Button>
                  {remove.isError && (
                    <p className="mt-1 text-sm text-[var(--danger)]">{(remove.error as Error).message}</p>
                  )}
                </div>
              )}
            </>
          ) : (
            <p className="text-sm text-muted">Загрузка…</p>
          )}
        </div>
      </aside>
    </div>
  );
}

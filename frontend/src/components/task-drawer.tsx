"use client";

import { AppIcon } from "@/components/ui/app-icon";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import type { ProjectMember, Status, Task, User } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { MultiSelect } from "@/components/ui/multi-select";
import { resolveColumnColors } from "@/lib/column-colors";
import { formatCreatedAt } from "@/lib/format-created-at";
import {
  formatDueAbsolute,
  formatDueChip,
  formatDueLabel,
  fromDatetimeLocalValue,
  isDueOverdue,
  toDatetimeLocalValue,
} from "@/lib/format-due-date";
import {
  URGENCY_OPTIONS,
  urgencyCssVars,
  urgencyFromPriority,
  urgencyLabel,
  urgencyOption,
} from "@/lib/urgency";
import { cn } from "@/lib/utils";
import { UserAvatar } from "@/components/user-avatar";
import { TaskAttachmentsPanel } from "@/components/task-attachments";
import { TaskActivityPanel } from "@/components/task-activity";

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
  const [editing, setEditing] = useState(false);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");

  useEffect(() => {
    setEditing(false);
  }, [taskId]);

  useEffect(() => {
    if (data?.task) {
      setTitle(data.task.title);
      setDescription(data.task.description ?? "");
    }
  }, [data?.task]);

  useEffect(() => {
    if (!taskId) return;
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") {
        if (editing) setEditing(false);
        else onClose();
      }
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [taskId, onClose, editing]);

  const patch = useMutation({
    mutationFn: (json: Record<string, unknown>) =>
      api(`/api/v1/tasks/${taskId}`, { method: "PATCH", json }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["tasks"] });
      qc.invalidateQueries({ queryKey: ["task", taskId] });
      qc.invalidateQueries({ queryKey: ["task-activity", taskId] });
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
    if (!editing || !taskId || !data?.task) return;
    const t = setTimeout(() => {
      if (title.trim() && title !== data.task.title) {
        patch.mutate({ title: title.trim() });
      }
    }, 600);
    return () => clearTimeout(t);
  }, [title, taskId, data?.task, patch, editing]);

  if (!taskId) return null;
  const task = data?.task;
  const assigneeIds = task?.assignees.map((a) => a.id) ?? [];
  const isAuthor = !!task && !!meData?.user && task.author_id === meData.user.id;
  const status = task ? statuses.find((s) => s.id === task.status_id) : undefined;
  const statusName = status?.name ?? "-";
  const createdLabel = task ? formatCreatedAt(task.created_at) : null;
  const urgency = task ? urgencyOption(task.priority) : null;
  const colColors = status ? resolveColumnColors(status.color) : null;

  return (
    <div className="fixed inset-0 z-50 flex justify-end" role="dialog" aria-modal="true" aria-label="Задача">
      <button type="button" className="absolute inset-0 bg-black/25" aria-label="Закрыть" onClick={onClose} />
      <aside
        className={cn(
          "relative z-10 flex h-full w-full flex-col border-l border-hairline bg-[var(--surface)] shadow-sm",
          "md:w-[480px] md:max-w-[520px]"
        )}
      >
        <div className="flex items-center justify-between gap-2 border-b border-hairline px-4 py-3">
          <h2 className="text-base font-semibold">{editing ? "Редактирование" : "Задача"}</h2>
          <div className="flex items-center gap-1">
            {task && !editing && (
              <Button type="button" variant="secondary" size="sm" onClick={() => setEditing(true)}>
                <AppIcon name="edit" size={16} /> Редактировать
              </Button>
            )}
            {editing && (
              <Button type="button" variant="ghost" size="sm" onClick={() => setEditing(false)}>
                Готово
              </Button>
            )}
            <Button variant="ghost" size="icon" aria-label="Закрыть" onClick={onClose}>
              <AppIcon name="close" size={20} />
            </Button>
          </div>
        </div>

        <div className="flex-1 space-y-4 overflow-y-auto p-4">
          {task ? (
            editing ? (
              <>
                <div>
                  <label className="label-text" htmlFor="drawer-title">
                    Название
                  </label>
                  <Input id="drawer-title" value={title} onChange={(e) => setTitle(e.target.value)} autoFocus />
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
                    onChange={(ids) => {
                      if (ids.length === 0) return;
                      patch.mutate({ assignee_ids: ids });
                    }}
                    options={members.map((m) => ({
                      value: m.user_id,
                      label: m.name,
                      avatarUrl: m.avatar_url,
                    }))}
                    placeholder="Выберите исполнителей"
                    minCount={1}
                  />
                </div>
                <div>
                  <label className="label-text" htmlFor="drawer-status">
                    Статус
                  </label>
                  <Select
                    id="drawer-status"
                    aria-label="Статус"
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
                <div>
                  <label className="label-text" htmlFor="drawer-due">
                    Срок
                  </label>
                  <div className="flex items-center gap-2">
                    <Input
                      id="drawer-due"
                      type="datetime-local"
                      className="min-w-0 flex-1"
                      value={toDatetimeLocalValue(task.due_date)}
                      onChange={(e) => {
                        const due_date = fromDatetimeLocalValue(e.target.value);
                        patch.mutate({ due_date });
                      }}
                    />
                    {task.due_date ? (
                      <Button
                        type="button"
                        size="sm"
                        variant="ghost"
                        onClick={() => patch.mutate({ due_date: null })}
                      >
                        Убрать
                      </Button>
                    ) : null}
                  </div>
                </div>
                <TaskAttachmentsPanel
                  taskId={task.id}
                  attachments={task.attachments ?? []}
                  editable
                  onChanged={() => {
                    qc.invalidateQueries({ queryKey: ["task", taskId] });
                    qc.invalidateQueries({ queryKey: ["tasks"] });
                    qc.invalidateQueries({ queryKey: ["task-activity", taskId] });
                  }}
                />
                <TaskActivityPanel taskId={task.id} />
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
                      <AppIcon name="delete" size={16} /> Удалить задачу
                    </Button>
                    {remove.isError && (
                      <p className="mt-1 text-sm text-[var(--danger)]">{(remove.error as Error).message}</p>
                    )}
                  </div>
                )}
              </>
            ) : (
              <>
                <div
                  className="overflow-hidden rounded-[var(--radius)] border bg-[var(--urgency-bg)] dark:bg-[var(--urgency-bg-dark)]"
                  style={{
                    ...urgencyCssVars(task.priority),
                    borderColor: colColors?.border ?? "var(--border)",
                    borderLeftWidth: 3,
                    borderLeftColor: urgency?.color ?? colColors?.value,
                  }}
                >
                  <div
                    className="h-1 w-full"
                    style={{ backgroundColor: colColors?.value ?? urgency?.color }}
                    aria-hidden
                  />
                  <div className="space-y-2 px-3 py-2.5">
                    <p className="text-sm leading-snug text-foreground">
                      <span className="text-muted">Срочность:</span>{" "}
                      <span
                        className="font-semibold text-[var(--urgency-fg)] dark:text-[var(--urgency-fg-dark)]"
                      >
                        {urgencyLabel(task.priority)}
                      </span>
                      <span className="mx-1.5 font-bold text-foreground" aria-hidden>
                        ·
                      </span>
                      <span className="text-muted">Статус:</span> {statusName}
                    </p>
                    {formatDueLabel(task.due_date, new Date(), {
                      isDone: Boolean(task.closed_at),
                    }) && (
                      <p className="text-sm leading-snug text-foreground">
                        <span className="text-muted">
                          {task.closed_at
                            ? "Срок:"
                            : isDueOverdue(task.due_date)
                              ? "Просрочено:"
                              : "До сдачи:"}
                        </span>{" "}
                        <span
                          className={cn(
                            "font-medium",
                            !task.closed_at && isDueOverdue(task.due_date)
                              ? "text-[var(--danger)]"
                              : undefined
                          )}
                        >
                          {formatDueChip(task.due_date, new Date(), {
                            isDone: Boolean(task.closed_at),
                          })}
                          {!task.closed_at && formatDueAbsolute(task.due_date)
                            ? ` · ${formatDueAbsolute(task.due_date)}`
                            : null}
                        </span>
                      </p>
                    )}
                    <div className="flex min-w-0 items-center gap-2">
                      {task.author?.name ? (
                        <>
                          <UserAvatar
                            name={task.author.name}
                            avatarUrl={task.author.avatar_url}
                            size={6}
                          />
                          <span className="min-w-0 truncate text-sm font-medium text-foreground">
                            {task.author.name}
                          </span>
                        </>
                      ) : (
                        <span className="text-sm text-muted">Без автора</span>
                      )}
                      {createdLabel && (
                        <>
                          <span className="text-muted" aria-hidden>
                            ·
                          </span>
                          <span className="shrink-0 text-sm text-muted">{createdLabel}</span>
                        </>
                      )}
                    </div>
                  </div>
                </div>
                <div>
                  <p className="label-text">Название</p>
                  <p className="text-[15px] font-semibold leading-snug text-foreground">{task.title}</p>
                </div>
                <div>
                  <p className="label-text">Описание</p>
                  {task.description?.trim() ? (
                    <p className="whitespace-pre-wrap text-sm leading-relaxed text-foreground">{task.description}</p>
                  ) : (
                    <p className="text-sm text-muted">Без описания</p>
                  )}
                </div>
                <div>
                  <p className="label-text">Исполнители</p>
                  {task.assignees.length ? (
                    <ul className="mt-1 space-y-1.5">
                      {task.assignees.map((a) => (
                        <li key={a.id} className="flex items-center gap-2 text-sm">
                          <UserAvatar name={a.name} avatarUrl={a.avatar_url} size={6} />
                          <span>{a.name}</span>
                        </li>
                      ))}
                    </ul>
                  ) : (
                    <p className="text-sm text-muted">Не назначены</p>
                  )}
                </div>
                <TaskAttachmentsPanel
                  taskId={task.id}
                  attachments={task.attachments ?? []}
                  editable={false}
                />
                <TaskActivityPanel taskId={task.id} />
              </>
            )
          ) : (
            <p className="text-sm text-muted">Загрузка…</p>
          )}
        </div>
      </aside>
    </div>
  );
}

"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import ReactMarkdown from "react-markdown";
import { Archive, ArrowLeft, Check, Copy, Link2, Trash2 } from "lucide-react";
import { api } from "@/lib/api";
import type { Status, Task, User } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { ErrorState } from "@/components/ui/error-state";
import { Skeleton } from "@/components/ui/skeleton";
import { priorityLabel } from "@/lib/utils";
import { UserAvatar } from "@/components/user-avatar";

type Comment = {
  id: string;
  body: string;
  author: { id: string; name: string; avatar_url: string | null };
  created_at: string;
};

export default function TaskPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const qc = useQueryClient();
  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ["task", id],
    queryFn: () => api<{ task: Task }>(`/api/v1/tasks/${id}`),
  });
  const task = data?.task;
  const { data: statusesData } = useQuery({
    queryKey: ["statuses", task?.project_id],
    enabled: !!task?.project_id,
    queryFn: () =>
      api<{ items: Status[] }>(`/api/v1/settings/statuses?project_id=${task!.project_id}`),
  });
  const { data: usersData } = useQuery({
    queryKey: ["users"],
    queryFn: () => api<{ items: User[] }>("/api/v1/users"),
    staleTime: 60_000,
  });
  const { data: commentsData, refetch: refetchComments } = useQuery({
    queryKey: ["comments", id],
    queryFn: () => api<{ items: Comment[] }>(`/api/v1/tasks/${id}/comments`),
  });
  const { data: activityData } = useQuery({
    queryKey: ["activity", id],
    queryFn: () =>
      api<{
        items: {
          id: string;
          action: string;
          field: string | null;
          user: { name: string };
          created_at: string;
        }[];
      }>(`/api/v1/tasks/${id}/activity`),
  });
  const { data: subtasksData, refetch: refetchSubtasks } = useQuery({
    queryKey: ["subtasks", id],
    queryFn: () => api<{ items: Task[] }>(`/api/v1/tasks?parent_id=${id}&page_size=100`),
  });

  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [labelInput, setLabelInput] = useState("");
  const [comment, setComment] = useState("");
  const [checklistTitle, setChecklistTitle] = useState("");
  const [subtaskTitle, setSubtaskTitle] = useState("");
  const [copied, setCopied] = useState(false);
  const [preview, setPreview] = useState(false);
  const [showHistory, setShowHistory] = useState(false);

  useEffect(() => {
    if (task) {
      setTitle(task.title);
      setDescription(task.description ?? "");
      setLabelInput(task.labels.map((l) => l.name).join(", "));
    }
  }, [task]);

  const patch = useMutation({
    mutationFn: (json: Record<string, unknown>) =>
      api(`/api/v1/tasks/${id}`, { method: "PATCH", json }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["task", id] });
      qc.invalidateQueries({ queryKey: ["tasks"] });
      qc.invalidateQueries({ queryKey: ["activity", id] });
    },
  });

  useEffect(() => {
    if (!task) return;
    const t = setTimeout(() => {
      if (title.trim() && title !== task.title) patch.mutate({ title: title.trim() });
    }, 700);
    return () => clearTimeout(t);
  }, [title, task, patch]);

  async function saveDescription() {
    if (!task) return;
    if ((task.description ?? "") !== description) {
      await patch.mutateAsync({ description });
    }
  }

  async function copyLink() {
    await navigator.clipboard.writeText(window.location.href);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  }

  const statuses = statusesData?.items ?? [];
  const doneStatus = useMemo(() => statuses.find((s) => s.is_done), [statuses]);
  const isDone = !!task?.closed_at || !!task?.status?.is_done;

  if (isLoading) {
    return (
      <div className="space-y-3">
        <Skeleton className="h-8 w-48" />
        <Skeleton className="h-48 w-full" />
      </div>
    );
  }
  if (isError || !task) {
    return (
      <ErrorState
        message={(error as Error)?.message || "Задача не найдена"}
        onRetry={() => refetch()}
      />
    );
  }

  const users = usersData?.items ?? [];
  const comments = commentsData?.items ?? [];
  const activity = activityData?.items ?? [];
  const subtasks = subtasksData?.items ?? [];
  const checklist = task.checklist_items ?? [];

  return (
    <div className="space-y-3 pb-20 lg:pb-0">
      <div className="flex flex-wrap items-center gap-2">
        <Button variant="ghost" size="sm" onClick={() => router.back()}>
          <ArrowLeft className="h-4 w-4" /> Назад
        </Button>
        {task.project_id && (
          <Button variant="ghost" size="sm" onClick={() => router.push(`/projects/${task.project_id}`)}>
            К доске
          </Button>
        )}
        <div className="ml-auto flex flex-wrap gap-2">
          {doneStatus && !isDone && (
            <Button
              size="sm"
              className="hidden sm:inline-flex"
              onClick={() => patch.mutate({ status_id: doneStatus.id })}
              disabled={patch.isPending}
            >
              <Check className="h-4 w-4" /> Отметить выполненной
            </Button>
          )}
          <Button variant="secondary" size="sm" onClick={copyLink} aria-label="Скопировать ссылку">
            <Link2 className="h-4 w-4" /> {copied ? "Скопировано" : "Ссылка"}
          </Button>
          <Button
            variant="secondary"
            size="sm"
            onClick={async () => {
              const res = await api<{ task: Task }>(`/api/v1/tasks/${id}/duplicate`, { method: "POST" });
              router.push(`/tasks/${res.task.id}`);
            }}
          >
            <Copy className="h-4 w-4" /> <span className="hidden sm:inline">Дублировать</span>
          </Button>
          <Button variant="secondary" size="sm" onClick={() => patch.mutate({ archived: !task.archived_at })}>
            <Archive className="h-4 w-4" /> <span className="hidden sm:inline">{task.archived_at ? "Из архива" : "В архив"}</span>
          </Button>
          <Button
            variant="destructive"
            size="sm"
            onClick={async () => {
              if (!confirm("Удалить задачу?")) return;
              await api(`/api/v1/tasks/${id}`, { method: "DELETE" });
              router.push(task.project_id ? `/projects/${task.project_id}` : "/projects");
            }}
          >
            <Trash2 className="h-4 w-4" /> <span className="hidden sm:inline">Удалить</span>
          </Button>
        </div>
      </div>

      <div className="grid gap-3 lg:grid-cols-[minmax(0,1fr)_280px]">
        <aside className="order-first lg:order-last lg:col-start-2 lg:row-span-2 lg:sticky lg:top-20 lg:self-start">
          <div className="surface-panel space-y-3 p-3 md:p-4">
            <p className="text-sm font-semibold">Параметры</p>
            <div>
              <label className="label-text" htmlFor="task-status">
                Статус
              </label>
              <select
                id="task-status"
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
              <label className="label-text" htmlFor="task-priority">
                Важность
              </label>
              <select
                id="task-priority"
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
            <div>
              <label className="label-text" htmlFor="task-due">
                Срок
              </label>
              <Input
                id="task-due"
                type="date"
                value={task.due_date ? task.due_date.slice(0, 10) : ""}
                onChange={(e) =>
                  patch.mutate({
                    due_date: e.target.value ? new Date(e.target.value).toISOString() : null,
                  })
                }
              />
            </div>
            <fieldset>
              <legend className="label-text">Кто выполняет</legend>
              <div className="max-h-40 space-y-0.5 overflow-y-auto rounded-xl border border-hairline bg-[var(--surface-2)] p-2 sm:max-h-48">
                {users.map((u) => {
                  const checked = task.assignees.some((a) => a.id === u.id);
                  return (
                    <label
                      key={u.id}
                      className="flex min-h-[44px] cursor-pointer items-center gap-3 rounded-lg px-2 text-sm hover:bg-[var(--surface)]"
                    >
                      <input
                        type="checkbox"
                        className="h-5 w-5 accent-[var(--accent)]"
                        checked={checked}
                        onChange={() => {
                          const ids = checked
                            ? task.assignees.filter((a) => a.id !== u.id).map((a) => a.id)
                            : [...task.assignees.map((a) => a.id), u.id];
                          patch.mutate({ assignee_ids: ids });
                        }}
                      />
                      <span>{u.name}</span>
                    </label>
                  );
                })}
              </div>
            </fieldset>
            <div>
              <label className="label-text" htmlFor="task-labels">
                Метки
              </label>
              <Input
                id="task-labels"
                placeholder="срочно, отчёт"
                value={labelInput}
                onChange={(e) => setLabelInput(e.target.value)}
                onBlur={() =>
                  patch.mutate({
                    label_names: labelInput
                      .split(",")
                      .map((x) => x.trim())
                      .filter(Boolean),
                  })
                }
              />
            </div>
            {task.author && (
              <p className="border-t border-hairline pt-2 text-xs text-muted">
                Создал(а): <span className="font-medium text-foreground">{task.author.name}</span>
              </p>
            )}
            {patch.isPending && <p className="text-xs text-muted">Сохранение…</p>}
          </div>
        </aside>

        <div className="space-y-3 lg:col-start-1">
          <section className="surface-panel p-3 md:p-4">
            <Input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="border-0 bg-transparent px-0 text-xl font-bold shadow-none focus-visible:ring-0 md:text-2xl"
              aria-label="Название задачи"
            />
            <div className="mt-2 flex items-center justify-between">
              <h3 className="text-sm font-semibold text-[var(--muted-fg)]">Описание</h3>
              <Button variant="ghost" size="sm" onClick={() => setPreview((v) => !v)}>
                {preview ? "Изменить" : "Просмотр"}
              </Button>
            </div>
            {preview ? (
              <div className="prose prose-sm mt-1 max-w-none dark:prose-invert">
                <ReactMarkdown>{description || "_Нет описания_"}</ReactMarkdown>
              </div>
            ) : (
              <textarea
                className="field mt-1 min-h-[100px] resize-y"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                onBlur={saveDescription}
                placeholder="Кратко опишите, что нужно сделать…"
              />
            )}
          </section>

          <section className="surface-panel p-3 md:p-4">
            <h3 className="mb-2 text-sm font-semibold">Чеклист</h3>
            <ul className="space-y-1">
              {checklist.map((item) => (
                <li key={item.id}>
                  <label className="flex min-h-[44px] cursor-pointer items-center gap-3 rounded-lg px-1 hover:bg-[var(--surface-2)]">
                    <input
                      type="checkbox"
                      className="h-5 w-5 shrink-0 accent-[var(--accent)]"
                      checked={item.is_done}
                      aria-checked={item.is_done}
                      onChange={async (e) => {
                        await api(`/api/v1/tasks/${id}/checklist/${item.id}`, {
                          method: "PATCH",
                          json: { is_done: e.target.checked },
                        });
                        qc.invalidateQueries({ queryKey: ["task", id] });
                      }}
                    />
                    <span className={item.is_done ? "text-sm text-muted line-through" : "text-sm"}>{item.title}</span>
                  </label>
                </li>
              ))}
              {!checklist.length && <li className="px-1 text-sm text-muted">Пока нет пунктов</li>}
            </ul>
            <form
              className="mt-2 flex gap-2"
              onSubmit={async (e) => {
                e.preventDefault();
                if (!checklistTitle.trim()) return;
                await api(`/api/v1/tasks/${id}/checklist`, {
                  method: "POST",
                  json: { title: checklistTitle.trim() },
                });
                setChecklistTitle("");
                qc.invalidateQueries({ queryKey: ["task", id] });
              }}
            >
              <Input
                placeholder="Новый пункт"
                aria-label="Новый пункт чеклиста"
                value={checklistTitle}
                onChange={(e) => setChecklistTitle(e.target.value)}
              />
              <Button type="submit" size="sm">
                Добавить
              </Button>
            </form>
          </section>

          <section className="surface-panel p-3 md:p-4">
            <h3 className="mb-2 text-sm font-semibold">Подзадачи</h3>
            <ul className="space-y-1">
              {subtasks.map((s) => (
                <li key={s.id}>
                  <button
                    type="button"
                    className="min-h-[40px] text-left text-sm font-medium text-[var(--accent)] hover:underline"
                    onClick={() => router.push(`/tasks/${s.id}`)}
                  >
                    {s.title}
                  </button>
                </li>
              ))}
              {!subtasks.length && <li className="text-sm text-muted">Нет подзадач</li>}
            </ul>
            <form
              className="mt-2 flex gap-2"
              onSubmit={async (e) => {
                e.preventDefault();
                if (!subtaskTitle.trim() || !task.project_id) return;
                await api("/api/v1/tasks", {
                  method: "POST",
                  json: {
                    title: subtaskTitle.trim(),
                    status_id: task.status_id,
                    project_id: task.project_id,
                    parent_id: task.id,
                    priority: "medium",
                  },
                });
                setSubtaskTitle("");
                refetchSubtasks();
              }}
            >
              <Input
                placeholder="Новая подзадача"
                aria-label="Новая подзадача"
                value={subtaskTitle}
                onChange={(e) => setSubtaskTitle(e.target.value)}
              />
              <Button type="submit" size="sm">
                Добавить
              </Button>
            </form>
          </section>

          <section className="surface-panel p-3 md:p-4">
            <h3 className="mb-2 text-sm font-semibold">Комментарии</h3>
            <ul className="mb-2 space-y-2">
              {comments.map((c) => (
                <li key={c.id} className="rounded-lg border border-hairline p-2.5">
                  <div className="mb-1 flex flex-wrap items-center gap-2 text-xs text-muted">
                    <UserAvatar name={c.author.name} avatarUrl={c.author.avatar_url} size={6} />
                    <span className="font-medium text-foreground">{c.author.name}</span>
                    <span>{new Date(c.created_at).toLocaleString("ru-RU")}</span>
                  </div>
                  <p className="whitespace-pre-wrap text-sm">{c.body}</p>
                </li>
              ))}
              {!comments.length && <li className="text-sm text-muted">Пока нет комментариев</li>}
            </ul>
            <form
              className="space-y-2"
              onSubmit={async (e) => {
                e.preventDefault();
                if (!comment.trim()) return;
                const mention_user_ids = users
                  .filter((u) => comment.includes(`@${u.name}`) || comment.includes(u.email))
                  .map((u) => u.id);
                await api(`/api/v1/tasks/${id}/comments`, {
                  method: "POST",
                  json: { body: comment.trim(), mention_user_ids },
                });
                setComment("");
                refetchComments();
                qc.invalidateQueries({ queryKey: ["notifications"] });
              }}
            >
              <label className="label-text" htmlFor="task-comment">
                Новый комментарий
              </label>
              <textarea
                id="task-comment"
                className="field min-h-[72px] resize-y"
                placeholder="Напишите сообщение. Можно упомянуть @Имя"
                value={comment}
                onChange={(e) => setComment(e.target.value)}
              />
              <Button type="submit" size="sm">
                Отправить
              </Button>
            </form>
          </section>

          <section className="surface-panel p-3 md:p-4">
            <button
              type="button"
              className="flex w-full items-center justify-between text-sm font-semibold"
              onClick={() => setShowHistory((v) => !v)}
              aria-expanded={showHistory}
            >
              История изменений
              <span className="text-xs font-normal text-muted">{showHistory ? "Скрыть" : "Показать"}</span>
            </button>
            {showHistory && (
              <ul className="mt-2 space-y-1.5 text-sm text-muted">
                {activity.map((a) => (
                  <li key={a.id}>
                    <span className="font-medium text-foreground">{a.user.name}</span> — {a.action}
                    {a.field ? ` (${a.field})` : ""} · {new Date(a.created_at).toLocaleString("ru-RU")}
                  </li>
                ))}
              </ul>
            )}
          </section>
        </div>
      </div>

      {doneStatus && !isDone && (
        <div className="fixed inset-x-0 bottom-[calc(3.25rem+env(safe-area-inset-bottom))] z-30 border-t border-hairline bg-[var(--surface)]/95 p-2 backdrop-blur sm:hidden">
          <Button
            className="w-full min-h-[44px]"
            onClick={() => patch.mutate({ status_id: doneStatus.id })}
            disabled={patch.isPending}
          >
            <Check className="h-4 w-4" /> Отметить выполненной
          </Button>
        </div>
      )}
    </div>
  );
}

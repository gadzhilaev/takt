"use client";

import * as SelectPrimitive from "@radix-ui/react-select";
import { Check, ChevronDown } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { ProjectMember, Status, Task, User } from "@/lib/types";
import { TaskCard } from "@/components/task-card";
import { UserAvatar } from "@/components/user-avatar";
import { columnShellStyle } from "@/lib/column-colors";
import { isProjectMember, memberTasksTitle, tasksForMember } from "@/lib/member-tasks";
import { cn } from "@/lib/utils";
import { useMediaQuery } from "@/hooks/use-media-query";

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
          <ChevronDown className="h-4 w-4 shrink-0 opacity-60" />
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
                    <Check className="h-3.5 w-3.5 text-[var(--accent)]" />
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
}: {
  projectId: string;
  members: ProjectMember[];
  statuses: Status[];
  tasks: Task[];
  onOpenTask: (taskId: string) => void;
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

  const byStatus = useMemo(() => {
    const map: Record<string, Task[]> = {};
    for (const s of statuses) map[s.id] = [];
    for (const t of filtered) {
      if (!map[t.status_id]) map[t.status_id] = [];
      map[t.status_id].push(t);
    }
    for (const id of Object.keys(map)) map[id].sort((a, b) => a.position - b.position);
    return map;
  }, [statuses, filtered]);

  if (!canShow || !meId) return null;

  const title = memberTasksTitle(members, effectiveId, meId);
  const empty = filtered.length === 0;
  const mobileStatus = statuses.find((s) => s.id === mobileStatusId) ?? statuses[0];
  const mobileTasks = mobileStatus ? byStatus[mobileStatus.id] ?? [] : [];

  return (
    <section
      className="max-h-[55%] min-h-[18rem] shrink-0 overflow-y-auto border-t border-hairline pt-3"
      aria-label={title}
    >
      <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
        <h2 className="text-sm font-semibold text-foreground">{title}</h2>
        <MemberSelect
          members={members}
          currentUserId={meId}
          value={effectiveId}
          onChange={setSelectedId}
        />
      </div>

      {empty ? (
        <p className="rounded-[var(--radius-lg)] border border-dashed border-hairline bg-[var(--surface)] px-4 py-6 text-center text-sm text-muted">
          У сотрудника пока нет задач
        </p>
      ) : isDesktop ? (
        <div className="flex items-stretch gap-3 overflow-x-auto pb-1">
          {statuses.map((status) => {
            const colTasks = byStatus[status.id] ?? [];
            return (
              <div key={status.id} className="flex w-[17.5rem] shrink-0 flex-col">
                <div
                  className="kanban-column-shell flex min-h-[16rem] w-full flex-1 flex-col overflow-hidden rounded-[var(--radius-lg)] border p-2"
                  style={columnShellStyle(status.color || "#607FA4")}
                >
                  <div className="kanban-column-accent mb-2 shrink-0" aria-hidden />
                  <div className="mb-2 flex shrink-0 items-center gap-1.5 px-1">
                    <h3 className="min-w-0 flex-1 truncate text-[13px] font-semibold">{status.name}</h3>
                    <span className="text-[11px] tabular-nums text-muted">{colTasks.length}</span>
                  </div>
                  <div className="flex max-h-72 min-h-0 flex-1 flex-col gap-2 overflow-y-auto">
                    {colTasks.map((task) => (
                      <TaskCard
                        key={task.id}
                        task={task}
                        draggable={false}
                        isDone={!!status.is_done}
                        onOpen={() => onOpenTask(task.id)}
                      />
                    ))}
                    {!colTasks.length && (
                      <p className="py-6 text-center text-[12px] text-muted">Пусто</p>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
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
              className="kanban-column-shell flex max-h-72 flex-col gap-2 overflow-y-auto rounded-[var(--radius-lg)] border p-2"
              style={columnShellStyle(mobileStatus.color || "#607FA4")}
            >
              {mobileTasks.map((task) => (
                <TaskCard
                  key={task.id}
                  task={task}
                  draggable={false}
                  isDone={!!mobileStatus.is_done}
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

"use client";

import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { useParams, usePathname, useRouter, useSearchParams } from "next/navigation";
import { api } from "@/lib/api";
import type { Project, User } from "@/lib/types";
import { KanbanBoard } from "@/components/kanban-board";
import { ErrorState } from "@/components/ui/error-state";
import { Skeleton } from "@/components/ui/skeleton";
import { Input } from "@/components/ui/input";

function ProjectBoardInner() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const [filtersOpen, setFiltersOpen] = useState(false);

  const search = searchParams.get("q") ?? "";
  const priority = searchParams.get("priority") ?? "";
  const assigneeId = searchParams.get("assignee") ?? "";
  const startCreate = searchParams.get("create") === "1";

  const setFilter = useCallback(
    (key: string, value: string) => {
      const next = new URLSearchParams(searchParams.toString());
      if (value) next.set(key, value);
      else next.delete(key);
      const qs = next.toString();
      router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
    },
    [pathname, router, searchParams]
  );

  useEffect(() => {
    if (!startCreate) return;
    const next = new URLSearchParams(searchParams.toString());
    next.delete("create");
    const qs = next.toString();
    const t = window.setTimeout(() => {
      router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
    }, 800);
    return () => window.clearTimeout(t);
  }, [startCreate, pathname, router, searchParams]);

  const projectQuery = useQuery({
    queryKey: ["project", id],
    queryFn: () => api<{ project: Project }>(`/api/v1/projects/${id}`),
  });
  const usersQuery = useQuery({
    queryKey: ["users"],
    queryFn: () => api<{ items: User[] }>("/api/v1/users"),
    staleTime: 60_000,
  });

  const users = usersQuery.data?.items ?? [];
  const project = projectQuery.data?.project;

  const progressLabel = useMemo(() => {
    if (!project?.progress) return "";
    return `Выполнено ${project.progress.done} из ${project.progress.total}`;
  }, [project]);

  if (projectQuery.isLoading) return <Skeleton className="h-64 w-full" />;
  if (projectQuery.isError || !project) {
    return (
      <ErrorState
        message={(projectQuery.error as Error)?.message || "Проект не найден"}
        onRetry={() => projectQuery.refetch()}
      />
    );
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div className="min-w-0">
          <div className="mb-1 flex items-center gap-2">
            <span className="h-3 w-3 shrink-0 rounded-full" style={{ background: project.color }} />
            <h1 className="page-title truncate">{project.name}</h1>
          </div>
          <p className="page-subtitle">
            {project.description?.replace(/\s*\[demo\]\s*/gi, "") || "Доска проекта"}
            {progressLabel ? ` · ${progressLabel}` : ""}
          </p>
          <p className="mt-1 hidden text-xs text-muted md:block">
            Подсказка: «Добавить задачу» в колонке или клавиша C · перетаскивание за ⋮⋮
          </p>
        </div>
        <div className="flex w-full flex-col gap-2 sm:w-auto">
          <button
            type="button"
            className="min-h-[44px] text-left text-sm font-semibold text-[var(--accent)] md:hidden"
            onClick={() => setFiltersOpen((v) => !v)}
          >
            {filtersOpen ? "Скрыть фильтры" : "Показать фильтры"}
          </button>
          <div className={filtersOpen ? "flex flex-col gap-2 sm:flex-row" : "hidden gap-2 md:flex"}>
            <Input
              placeholder="Искать на доске…"
              aria-label="Фильтр задач на доске"
              value={search}
              onChange={(e) => setFilter("q", e.target.value)}
              className="sm:w-48"
            />
            <select
              className="field sm:w-40"
              value={priority}
              onChange={(e) => setFilter("priority", e.target.value)}
              aria-label="Фильтр по важности"
            >
              <option value="">Важность: все</option>
              <option value="urgent">Срочный</option>
              <option value="high">Высокий</option>
              <option value="medium">Средний</option>
              <option value="low">Низкий</option>
            </select>
            <select
              className="field sm:w-48"
              value={assigneeId}
              onChange={(e) => setFilter("assignee", e.target.value)}
              aria-label="Фильтр по исполнителю"
            >
              <option value="">Исполнитель: все</option>
              {users.map((u) => (
                <option key={u.id} value={u.id}>
                  {u.name}
                </option>
              ))}
            </select>
          </div>
        </div>
      </div>
      <KanbanBoard
        projectId={id}
        search={search}
        priority={priority || undefined}
        assigneeId={assigneeId || undefined}
        startCreate={startCreate}
      />
    </div>
  );
}

export default function ProjectBoardPage() {
  return (
    <Suspense fallback={<Skeleton className="h-64 w-full" />}>
      <ProjectBoardInner />
    </Suspense>
  );
}

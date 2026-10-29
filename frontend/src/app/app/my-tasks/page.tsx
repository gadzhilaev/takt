"use client";

import { useEffect } from "react";
import { useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { api } from "@/lib/api";
import type { Project, Task, User } from "@/lib/types";
import { getLastProjectId } from "@/lib/last-project";
import { paths } from "@/lib/paths";
import { Skeleton } from "@/components/ui/skeleton";
import { ErrorState } from "@/components/ui/error-state";
import { TaskCard } from "@/components/task-card";
import { EmptyState } from "@/components/ui/empty-state";

/** Tasks assigned to the current user across the last/open project. */
export default function MyTasksPage() {
  const router = useRouter();
  const me = useQuery({
    queryKey: ["me"],
    queryFn: () => api<{ user: User }>("/api/v1/auth/me"),
  });
  const projects = useQuery({
    queryKey: ["projects"],
    queryFn: () => api<{ items: Project[] }>("/api/v1/projects"),
  });

  const projectId =
    getLastProjectId() ||
    projects.data?.items.find((p) => p.is_default)?.id ||
    projects.data?.items[0]?.id;

  const board = useQuery({
    queryKey: ["tasks", projectId, "mine"],
    enabled: !!projectId && !!me.data?.user.id,
    queryFn: () =>
      api<{ items: Task[] }>(`/api/v1/tasks?project_id=${projectId}&assignee_id=${me.data!.user.id}`),
  });

  useEffect(() => {
    if (projects.isSuccess && !projects.data.items.length) {
      router.replace(`${paths.projects}?new=1`);
    }
  }, [projects.isSuccess, projects.data, router]);

  if (me.isLoading || projects.isLoading) return <Skeleton className="h-48 w-full" />;
  if (me.isError || projects.isError) {
    return <ErrorState message="Не удалось загрузить задачи" onRetry={() => projects.refetch()} />;
  }
  if (!projectId) return null;

  const tasks = board.data?.items ?? [];

  return (
    <div className="mx-auto max-w-3xl space-y-5 px-1 py-2">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">Мои задачи</h1>
        <p className="mt-1 text-sm text-muted">Назначенные вам задачи в текущем проекте.</p>
      </div>
      {board.isLoading ? (
        <Skeleton className="h-40 w-full" />
      ) : board.isError ? (
        <ErrorState message={(board.error as Error).message} onRetry={() => board.refetch()} />
      ) : tasks.length === 0 ? (
        <EmptyState title="Нет назначенных задач" description="Когда вас назначат исполнителем, задачи появятся здесь." />
      ) : (
        <ul className="space-y-2">
          {tasks.map((task) => (
            <li key={task.id}>
              <TaskCard
                task={task}
                draggable={false}
                onOpen={() => router.push(paths.projectTask(projectId, task.id))}
              />
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

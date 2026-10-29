"use client";

import { useQuery } from "@tanstack/react-query";
import { useParams, useRouter } from "next/navigation";
import { useEffect } from "react";
import { api } from "@/lib/api";
import type { Task } from "@/lib/types";
import { ErrorState } from "@/components/ui/error-state";
import { Skeleton } from "@/components/ui/skeleton";

/** Deep links open the task overlay on the project board. */
export default function TaskPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ["task", id],
    queryFn: () => api<{ task: Task }>(`/api/v1/tasks/${id}`),
  });

  useEffect(() => {
    const task = data?.task;
    if (!task?.project_id) return;
    router.replace(`/app/projects/${task.project_id}?task=${task.id}`);
  }, [data?.task, router]);

  if (isLoading) {
    return (
      <div className="mx-auto max-w-xl space-y-3">
        <Skeleton className="h-8 w-40" />
        <Skeleton className="h-40 w-full" />
      </div>
    );
  }

  if (isError || !data?.task) {
    return (
      <ErrorState
        message={(error as Error)?.message || "Задача не найдена"}
        onRetry={() => refetch()}
      />
    );
  }

  if (!data.task.project_id) {
    return <ErrorState message="У задачи нет проекта" onRetry={() => refetch()} />;
  }

  return (
    <div className="mx-auto max-w-xl space-y-3">
      <Skeleton className="h-8 w-40" />
      <p className="text-sm text-muted">Открываем на доске…</p>
    </div>
  );
}

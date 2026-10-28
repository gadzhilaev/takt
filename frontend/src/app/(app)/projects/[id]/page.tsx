"use client";

import { Suspense, useEffect } from "react";
import { useQuery } from "@tanstack/react-query";
import { useParams, usePathname, useRouter, useSearchParams } from "next/navigation";
import { api } from "@/lib/api";
import type { Project } from "@/lib/types";
import { KanbanBoard } from "@/components/kanban-board";
import { ErrorState } from "@/components/ui/error-state";
import { Skeleton } from "@/components/ui/skeleton";
import { setLastProjectId } from "@/lib/last-project";

function ProjectBoardInner() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const startCreate = searchParams.get("new") === "1" || searchParams.get("create") === "1";

  useEffect(() => {
    if (id) setLastProjectId(id);
  }, [id]);

  useEffect(() => {
    if (!startCreate) return;
    const next = new URLSearchParams(searchParams.toString());
    next.delete("new");
    next.delete("create");
    const qs = next.toString();
    const t = window.setTimeout(() => {
      router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
    }, 400);
    return () => window.clearTimeout(t);
  }, [startCreate, pathname, router, searchParams]);

  const projectQuery = useQuery({
    queryKey: ["project", id],
    queryFn: () => api<{ project: Project }>(`/api/v1/projects/${id}`),
  });

  if (projectQuery.isLoading) return <Skeleton className="h-64 w-full" />;
  if (projectQuery.isError || !projectQuery.data?.project) {
    return (
      <ErrorState
        message={(projectQuery.error as Error)?.message || "Проект не найден"}
        onRetry={() => projectQuery.refetch()}
      />
    );
  }

  const project = projectQuery.data.project;

  return (
    <KanbanBoard
      projectId={id}
      members={project.members}
      startCreate={startCreate}
    />
  );
}

export default function ProjectBoardPage() {
  return (
    <Suspense fallback={<Skeleton className="h-64 w-full" />}>
      <ProjectBoardInner />
    </Suspense>
  );
}

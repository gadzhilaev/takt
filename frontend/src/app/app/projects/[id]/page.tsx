"use client";

import { Suspense, useEffect } from "react";
import { useQuery } from "@tanstack/react-query";
import { useParams, usePathname, useRouter, useSearchParams } from "next/navigation";
import { api } from "@/lib/api";
import type { Project } from "@/lib/types";
import { KanbanBoard } from "@/components/kanban-board";
import { Skeleton } from "@/components/ui/skeleton";
import { clearLastProjectId, setLastProjectId } from "@/lib/last-project";

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

  // Удалённый / чужой project id в URL — на экран создания / список, без ErrorState.
  useEffect(() => {
    if (projectQuery.isLoading) return;
    if (!projectQuery.isError && projectQuery.data?.project) return;
    clearLastProjectId();
    router.replace("/app/projects");
  }, [projectQuery.isLoading, projectQuery.isError, projectQuery.data?.project, router]);

  if (projectQuery.isLoading) return <Skeleton className="h-64 w-full shrink-0" />;
  if (projectQuery.isError || !projectQuery.data?.project) {
    return <Skeleton className="h-64 w-full shrink-0" />;
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
    <div className="flex min-h-0 flex-1 flex-col">
      <Suspense fallback={<Skeleton className="h-64 w-full shrink-0" />}>
        <ProjectBoardInner />
      </Suspense>
    </div>
  );
}

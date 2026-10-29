"use client";

import { Suspense, useEffect, useMemo, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { api } from "@/lib/api";
import type { Project } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { ErrorState } from "@/components/ui/error-state";
import { Skeleton } from "@/components/ui/skeleton";
import { getLastProjectId, setLastProjectId } from "@/lib/last-project";

function ProjectsInner() {
  const qc = useQueryClient();
  const router = useRouter();
  const searchParams = useSearchParams();
  const browse = searchParams.get("browse") === "1";
  const wantNew = searchParams.get("new") === "1";
  const [name, setName] = useState("");

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ["projects"],
    queryFn: () => api<{ items: Project[] }>("/api/v1/projects"),
  });
  const projects = useMemo(() => data?.items ?? [], [data?.items]);

  useEffect(() => {
    if (isLoading || !data) return;
    if (browse || wantNew) return;
    if (!projects.length) return;
    const last = getLastProjectId();
    const lastProject = last ? projects.find((p) => p.id === last) : undefined;
    // Prefer college demo board over stale last-id pointing at archived/tech boards.
    const college = projects.find((p) => p.name === "Колледж ДГУ");
    const target =
      (lastProject && lastProject.name !== "Демо-доска" ? lastProject : undefined) ||
      college ||
      projects.find((p) => p.is_default) ||
      projects[0];
    if (target) {
      setLastProjectId(target.id);
      router.replace(`/app/projects/${target.id}`);
    }
  }, [browse, data, isLoading, projects, router, wantNew]);

  const create = useMutation({
    mutationFn: () =>
      api<{ project: Project }>("/api/v1/projects", {
        method: "POST",
        json: {
          name: name.trim(),
          description: null,
          color: "#315F72",
          icon: "folder",
          member_ids: [],
        },
      }),
    onSuccess: (res) => {
      qc.invalidateQueries({ queryKey: ["projects"] });
      setLastProjectId(res.project.id);
      router.replace(`/app/projects/${res.project.id}`);
    },
  });

  if (isLoading) return <Skeleton className="h-40 w-full max-w-md" />;
  if (isError) return <ErrorState message={(error as Error).message} onRetry={() => refetch()} />;

  if (!projects.length || wantNew) {
    return (
      <div className="mx-auto max-w-md space-y-5 pt-8">
        <div>
          <h1 className="text-xl font-semibold tracking-tight">
            {projects.length ? "Новый проект" : "Создайте первый проект"}
          </h1>
          <p className="mt-1 text-sm text-muted">
            Доска откроется сразу: столбцы «К выполнению», «В работе», «На проверке», «Готово».
          </p>
        </div>
        <form
          className="space-y-3"
          onSubmit={(e) => {
            e.preventDefault();
            if (name.trim()) create.mutate();
          }}
        >
          <div>
            <label className="label-text" htmlFor="project-name">
              Название проекта
            </label>
            <Input
              id="project-name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Например: Команда продукта"
              autoFocus
            />
          </div>
          <Button type="submit" disabled={!name.trim() || create.isPending} className="w-full">
            Создать проект
          </Button>
          {projects.length > 0 && (
            <Button type="button" variant="ghost" className="w-full" onClick={() => router.back()}>
              Отмена
            </Button>
          )}
          {create.isError && (
            <p className="text-sm text-[var(--danger)]">{(create.error as Error).message}</p>
          )}
        </form>
      </div>
    );
  }

  if (browse) {
    return (
      <div className="mx-auto max-w-lg space-y-4 pt-4">
        <div className="flex items-center justify-between gap-3">
          <h1 className="text-lg font-semibold">Проекты</h1>
          <Button size="sm" onClick={() => router.push("/app/projects?new=1")}>
            Новый
          </Button>
        </div>
        <ul className="divide-y divide-hairline rounded-[var(--radius-lg)] border border-hairline bg-[var(--surface)]">
          {projects.map((p) => (
            <li key={p.id}>
              <Link
                href={`/app/projects/${p.id}`}
                className="flex items-center gap-2 px-3 py-3 text-sm hover:bg-[var(--surface-2)]"
                onClick={() => setLastProjectId(p.id)}
              >
                <span className="h-2.5 w-2.5 rounded-full" style={{ background: p.color }} />
                <span className="font-medium">{p.name}</span>
              </Link>
            </li>
          ))}
        </ul>
      </div>
    );
  }

  return <p className="text-sm text-muted">Открываем доску…</p>;
}

export default function ProjectsPage() {
  return (
    <Suspense fallback={<Skeleton className="h-40 w-full max-w-md" />}>
      <ProjectsInner />
    </Suspense>
  );
}

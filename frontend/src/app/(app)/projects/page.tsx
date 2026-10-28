"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useState } from "react";
import { Plus } from "lucide-react";
import { api } from "@/lib/api";
import type { Project, User } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { ErrorState } from "@/components/ui/error-state";
import { EmptyState } from "@/components/ui/empty-state";
import { Skeleton } from "@/components/ui/skeleton";

function ProjectsPageInner() {
  const qc = useQueryClient();
  const router = useRouter();
  const searchParams = useSearchParams();
  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [color, setColor] = useState("#315F72");

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ["projects"],
    queryFn: () => api<{ items: Project[] }>("/api/v1/projects"),
  });

  useEffect(() => {
    if (searchParams.get("create") !== "1" || !data?.items?.length) return;
    const target = data.items.find((p) => p.is_default) ?? data.items[0];
    router.replace(`/projects/${target.id}?create=1`);
  }, [data?.items, router, searchParams]);
  const { data: usersData } = useQuery({
    queryKey: ["users"],
    queryFn: () => api<{ items: User[] }>("/api/v1/users"),
  });

  const create = useMutation({
    mutationFn: () =>
      api<{ project: Project }>("/api/v1/projects", {
        method: "POST",
        json: {
          name,
          description: description || null,
          color,
          icon: "folder",
          member_ids: (usersData?.items ?? []).map((u) => u.id),
        },
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["projects"] });
      setOpen(false);
      setName("");
      setDescription("");
    },
  });

  if (isLoading) return <Skeleton className="h-48 w-full" />;
  if (isError) return <ErrorState message={(error as Error).message} onRetry={() => refetch()} />;

  const projects = data?.items ?? [];

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="page-title">Проекты</h1>
          <p className="page-subtitle">Откройте доску проекта, чтобы видеть и двигать задачи</p>
        </div>
        <Button onClick={() => setOpen((v) => !v)}>
          <Plus className="h-4 w-4" /> Новый проект
        </Button>
      </div>

      {open && (
        <form
          className="surface-card grid gap-3 p-4 md:grid-cols-2"
          onSubmit={(e) => {
            e.preventDefault();
            if (name.trim()) create.mutate();
          }}
        >
          <Input placeholder="Название" value={name} onChange={(e) => setName(e.target.value)} required />
          <Input type="color" value={color} onChange={(e) => setColor(e.target.value)} aria-label="Цвет" />
          <Input
            className="md:col-span-2"
            placeholder="Описание"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
          />
          <div className="flex gap-2 md:col-span-2">
            <Button type="submit" disabled={create.isPending}>
              Создать
            </Button>
            <Button type="button" variant="ghost" onClick={() => setOpen(false)}>
              Отмена
            </Button>
          </div>
        </form>
      )}

      {!projects.length ? (
        <EmptyState title="Пока нет проектов" description="Создайте первый проект для доски задач" />
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {projects.map((p) => (
            <Link key={p.id} href={`/projects/${p.id}`} className="surface-panel block p-4 transition hover:border-[var(--border-strong)] hover:bg-[var(--surface-2)]">
              <div className="mb-3 flex items-center gap-2">
                <span className="h-3.5 w-3.5 rounded-full" style={{ background: p.color }} />
                <h2 className="text-lg font-semibold">{p.name}</h2>
              </div>
              <p className="mb-4 line-clamp-2 text-sm text-muted">{p.description || "Без описания"}</p>
              <div className="mb-2 h-1.5 overflow-hidden rounded-full bg-[var(--surface-2)]">
                <div className="h-full bg-[var(--accent)]" style={{ width: `${p.progress?.percent ?? 0}%` }} />
              </div>
              <div className="text-xs text-muted">
                {p.progress?.done ?? 0} из {p.progress?.total ?? 0} · {p.members.length} участников
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}

export default function ProjectsPage() {
  return (
    <Suspense fallback={<Skeleton className="h-64 w-full" />}>
      <ProjectsPageInner />
    </Suspense>
  );
}

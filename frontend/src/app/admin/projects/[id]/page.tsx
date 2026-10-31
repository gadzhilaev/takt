"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { DataTable, type DataTableColumn } from "@/components/admin/data-table";
import { useMemo } from "react";

type Member = {
  user_id: string;
  name: string;
  email: string;
  role: string;
  joined_at?: string | null;
};

type ProjectCard = {
  id: string;
  name: string;
  member_count: number;
  task_count: number;
  restricted: boolean;
  restriction_reason?: string | null;
  created_at?: string | null;
  is_demo?: boolean;
  is_archived?: boolean;
  members: Member[];
};

const ROLE_LABELS: Record<string, string> = {
  admin: "Админ проекта",
  member: "Участник",
  viewer: "Наблюдатель",
};

export default function AdminProjectDetailPage() {
  const { id } = useParams<{ id: string }>();
  const qc = useQueryClient();
  const { data, isLoading, error } = useQuery({
    queryKey: ["platform-project", id],
    queryFn: () => api<ProjectCard>(`/api/v1/platform/projects/${id}`),
  });

  const restrict = useMutation({
    mutationFn: (reason: string) =>
      api(`/api/v1/platform/projects/${id}/restrict`, { method: "POST", json: { reason } }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["platform-project", id] });
      qc.invalidateQueries({ queryKey: ["platform-projects"] });
    },
  });
  const unrestrict = useMutation({
    mutationFn: () => api(`/api/v1/platform/projects/${id}/unrestrict`, { method: "POST" }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["platform-project", id] });
      qc.invalidateQueries({ queryKey: ["platform-projects"] });
    },
  });

  const columns = useMemo<DataTableColumn<Member>[]>(
    () => [
      {
        id: "name",
        label: "Имя",
        width: 200,
        cell: (m) => (
          <Link href={`/admin/users/${m.user_id}`} className="font-medium text-[var(--accent)]">
            {m.name}
          </Link>
        ),
      },
      {
        id: "email",
        label: "Email",
        width: 220,
        className: "text-muted",
        cell: (m) => m.email,
      },
      {
        id: "role",
        label: "Роль в проекте",
        width: 140,
        cell: (m) => ROLE_LABELS[m.role] ?? m.role,
      },
      {
        id: "joined_at",
        label: "Вступил",
        width: 160,
        className: "tabular-nums text-muted",
        cell: (m) =>
          m.joined_at ? new Date(m.joined_at).toLocaleString("ru-RU") : "—",
      },
    ],
    []
  );

  if (isLoading) return <p className="text-sm text-muted">Загрузка…</p>;
  if (error) return <p className="text-sm text-[var(--danger)]">{(error as Error).message}</p>;
  if (!data) return null;

  return (
    <div className="space-y-4">
      <div>
        <Link href="/admin/projects" className="text-[13px] text-[var(--accent)]">
          ← К проектам
        </Link>
        <h1 className="mt-2 text-xl font-semibold tracking-tight">{data.name}</h1>
        <p className="mt-1 text-[13px] text-muted">
          {data.member_count} уч. · {data.task_count} задач
          {data.is_demo ? " · демо" : ""}
          {data.is_archived ? " · архив" : ""}
          {data.created_at
            ? ` · создан ${new Date(data.created_at).toLocaleDateString("ru-RU")}`
            : ""}
        </p>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        {data.restricted ? (
          <>
            <span className="text-[13px] text-[var(--danger)]">
              Ограничен{data.restriction_reason ? `: ${data.restriction_reason}` : ""}
            </span>
            <Button
              type="button"
              size="sm"
              variant="secondary"
              disabled={unrestrict.isPending}
              onClick={() => unrestrict.mutate()}
            >
              Снять ограничение
            </Button>
          </>
        ) : (
          <Button
            type="button"
            size="sm"
            variant="secondary"
            disabled={restrict.isPending}
            onClick={() => {
              const reason = window.prompt("Причина ограничения");
              if (reason && reason.trim().length >= 3) restrict.mutate(reason.trim());
            }}
          >
            Ограничить
          </Button>
        )}
      </div>

      <div>
        <h2 className="mb-2 text-[14px] font-semibold">Участники</h2>
        <DataTable
          storageKey="takt-admin-project-members-cols"
          columns={columns}
          rows={data.members}
          rowKey={(m) => m.user_id}
          empty="Участников нет"
        />
        <p className="mt-2 text-[11px] text-muted">Тексты задач не показываются.</p>
      </div>
    </div>
  );
}

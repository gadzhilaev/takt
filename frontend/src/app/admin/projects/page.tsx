"use client";

import Link from "next/link";
import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo } from "react";
import { api } from "@/lib/api";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { useSessionState } from "@/lib/use-session-state";
import { nextSort, type SortDir } from "@/components/admin/sortable-th";
import { DataTable, type DataTableColumn } from "@/components/admin/data-table";

type ProjectRow = {
  id: string;
  name: string;
  task_count: number;
  member_count: number;
  restricted: boolean;
  restriction_reason?: string | null;
  created_at?: string | null;
  is_demo?: boolean;
  is_archived?: boolean;
  owner?: { email: string; name?: string } | null;
};

const PAGE_SIZE = 20;

export default function AdminProjectsPage() {
  const [q, setQ] = useSessionState<string>("takt-admin-projects-q", "");
  const [page, setPage] = useSessionState<number>("takt-admin-projects-page", 1);
  const [sort, setSort] = useSessionState<string>("takt-admin-projects-sort", "created_at");
  const [dir, setDir] = useSessionState<SortDir>("takt-admin-projects-dir", "desc");
  const qc = useQueryClient();

  const { data, isLoading, isFetching } = useQuery({
    queryKey: ["platform-projects", q, page, sort, dir],
    queryFn: () => {
      const sp = new URLSearchParams({
        page: String(page),
        page_size: String(PAGE_SIZE),
        sort,
        sort_dir: dir,
      });
      if (q.trim()) sp.set("q", q.trim());
      return api<{ items: ProjectRow[]; total: number }>(`/api/v1/platform/projects?${sp}`);
    },
    placeholderData: keepPreviousData,
  });

  const restrict = useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) =>
      api(`/api/v1/platform/projects/${id}/restrict`, { method: "POST", json: { reason } }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["platform-projects"] }),
  });

  const unrestrict = useMutation({
    mutationFn: (id: string) =>
      api(`/api/v1/platform/projects/${id}/unrestrict`, { method: "POST" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["platform-projects"] }),
  });

  const total = data?.total ?? 0;
  const pageCount = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const showPager = total > PAGE_SIZE;
  const rows = data?.items ?? [];

  const onSort = (column: string) => {
    const next = nextSort(sort, dir, column);
    setSort(next.sort);
    setDir(next.dir);
    setPage(1);
  };

  const columns = useMemo<DataTableColumn<ProjectRow>[]>(
    () => [
      {
        id: "name",
        label: "Название",
        width: 220,
        sortable: true,
        cell: (p) => (
          <>
            <Link href={`/admin/projects/${p.id}`} className="font-medium text-[var(--accent)]">
              {p.name}
            </Link>
            {p.is_demo ? <span className="ml-2 text-[11px] text-muted">демо</span> : null}
            {p.is_archived ? <span className="ml-2 text-[11px] text-muted">архив</span> : null}
          </>
        ),
      },
      {
        id: "owner",
        label: "Владелец",
        width: 200,
        className: "text-muted",
        cell: (p) => p.owner?.email ?? "—",
      },
      {
        id: "member_count",
        label: "Участники",
        width: 110,
        sortable: true,
        className: "tabular-nums",
        cell: (p) => p.member_count,
      },
      {
        id: "task_count",
        label: "Задачи",
        width: 100,
        sortable: true,
        className: "tabular-nums",
        cell: (p) => p.task_count,
      },
      {
        id: "created_at",
        label: "Создан",
        width: 120,
        sortable: true,
        className: "tabular-nums text-muted",
        cell: (p) =>
          p.created_at ? new Date(p.created_at).toLocaleDateString("ru-RU") : "—",
      },
      {
        id: "restricted",
        label: "Статус",
        width: 110,
        sortable: true,
        cell: (p) =>
          p.restricted ? (
            <span className="text-[var(--danger)]" title={p.restriction_reason ?? undefined}>
              Ограничен
            </span>
          ) : (
            <span className="text-muted">Обычный</span>
          ),
      },
      {
        id: "actions",
        label: "Действие",
        width: 120,
        cell: (p) =>
          p.restricted ? (
            <Button
              type="button"
              size="sm"
              variant="secondary"
              disabled={unrestrict.isPending}
              onClick={(e) => {
                e.preventDefault();
                e.stopPropagation();
                if (window.confirm(`Снять ограничение с «${p.name}»?`)) {
                  unrestrict.mutate(p.id);
                }
              }}
            >
              Снять
            </Button>
          ) : (
            <Button
              type="button"
              size="sm"
              variant="secondary"
              disabled={restrict.isPending}
              onClick={(e) => {
                e.preventDefault();
                e.stopPropagation();
                const reason = window.prompt(
                  "Причина ограничения (участники не смогут открыть доску)"
                );
                if (reason && reason.trim().length >= 3) {
                  restrict.mutate({ id: p.id, reason: reason.trim() });
                }
              }}
            >
              Ограничить
            </Button>
          ),
      },
    ],
    [restrict, unrestrict]
  );

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">Проекты</h1>
        <p className="mt-1 text-[13px] text-muted">
          Клик по названию — участники. Ограничить = заморозка доски (не удаление).
        </p>
      </div>
      <Input
        placeholder="Поиск по названию"
        value={q}
        onChange={(e) => {
          setPage(1);
          setQ(e.target.value);
        }}
        className="max-w-sm"
      />
      {isLoading && !data ? (
        <p className="text-sm text-muted">Загрузка…</p>
      ) : (
        <DataTable
          storageKey="takt-admin-projects-cols"
          columns={columns}
          rows={rows}
          rowKey={(p) => p.id}
          sort={sort}
          dir={dir}
          onSort={onSort}
          isFetching={isFetching && !isLoading}
          empty="Проекты не найдены"
        />
      )}
      {showPager && (
        <div className="flex flex-wrap items-center gap-2">
          <Button
            type="button"
            size="sm"
            variant="secondary"
            disabled={page <= 1}
            onClick={() => setPage(Math.max(1, page - 1))}
          >
            Назад
          </Button>
          <span className="text-[12px] text-muted">
            стр. {page} из {pageCount} · всего {total}
          </span>
          <Button
            type="button"
            size="sm"
            variant="secondary"
            disabled={page >= pageCount}
            onClick={() => setPage(page + 1)}
          >
            Далее
          </Button>
        </div>
      )}
    </div>
  );
}

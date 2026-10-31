"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { useSessionState } from "@/lib/use-session-state";
import { nextSort, SortableTh, type SortDir } from "@/components/admin/sortable-th";

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

  const { data, isLoading } = useQuery({
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

  const onSort = (column: string) => {
    const next = nextSort(sort, dir, column);
    setSort(next.sort);
    setDir(next.dir);
    setPage(1);
  };

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">Проекты</h1>
        <p className="mt-1 text-[13px] text-muted">
          Только названия и счётчики — тексты задач платформенный админ не видит.
        </p>
        <p className="mt-2 max-w-3xl rounded-[var(--radius)] border border-[var(--border)] bg-[#f7f8fa] px-3 py-2 text-[12px] leading-snug text-muted">
          <span className="font-medium text-foreground">Ограничить</span> — заморозка доски для всех
          участников: открыть проект и править задачи нельзя, пока ограничение не снимете. Причина
          пишется в журнал. Это не удаление и не архив.
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
      {isLoading ? (
        <p className="text-sm text-muted">Загрузка…</p>
      ) : (
        <div className="overflow-x-auto rounded-[var(--radius)] border border-[var(--border)] bg-white">
          <table className="w-full min-w-[900px] text-left text-[13px]">
            <thead className="border-b border-[var(--border)] text-muted">
              <tr>
                <SortableTh label="Название" column="name" sort={sort} dir={dir} onSort={onSort} />
                <th className="px-3 py-2 font-medium">Владелец</th>
                <SortableTh
                  label="Участники"
                  column="member_count"
                  sort={sort}
                  dir={dir}
                  onSort={onSort}
                />
                <SortableTh
                  label="Задачи"
                  column="task_count"
                  sort={sort}
                  dir={dir}
                  onSort={onSort}
                />
                <SortableTh
                  label="Создан"
                  column="created_at"
                  sort={sort}
                  dir={dir}
                  onSort={onSort}
                />
                <SortableTh
                  label="Статус"
                  column="restricted"
                  sort={sort}
                  dir={dir}
                  onSort={onSort}
                />
                <th className="px-3 py-2 font-medium">Действие</th>
              </tr>
            </thead>
            <tbody>
              {(data?.items ?? []).map((p) => (
                <tr key={p.id} className="border-b border-[var(--border)] last:border-0">
                  <td className="px-3 py-2">
                    <span className="font-medium">{p.name}</span>
                    {p.is_demo ? (
                      <span className="ml-2 text-[11px] text-muted">демо</span>
                    ) : null}
                    {p.is_archived ? (
                      <span className="ml-2 text-[11px] text-muted">архив</span>
                    ) : null}
                  </td>
                  <td className="px-3 py-2 text-muted">{p.owner?.email ?? "—"}</td>
                  <td className="px-3 py-2 tabular-nums">{p.member_count}</td>
                  <td className="px-3 py-2 tabular-nums">{p.task_count}</td>
                  <td className="px-3 py-2 tabular-nums text-muted">
                    {p.created_at ? new Date(p.created_at).toLocaleDateString("ru-RU") : "—"}
                  </td>
                  <td className="px-3 py-2">
                    {p.restricted ? (
                      <span className="text-[var(--danger)]" title={p.restriction_reason ?? undefined}>
                        Ограничен
                      </span>
                    ) : (
                      <span className="text-muted">Обычный</span>
                    )}
                  </td>
                  <td className="px-3 py-2">
                    {p.restricted ? (
                      <Button
                        type="button"
                        size="sm"
                        variant="secondary"
                        disabled={unrestrict.isPending}
                        onClick={() => {
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
                        onClick={() => {
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
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
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

"use client";

import Link from "next/link";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import { useSessionState } from "@/lib/use-session-state";
import { loginMethodsLabel, platformRoleLabel } from "@/lib/types";
import { nextSort, SortableTh, type SortDir } from "@/components/admin/sortable-th";

type UserRow = {
  id: string;
  name: string;
  email: string;
  platform_role: string;
  is_active: boolean;
  created_at: string | null;
  last_login_at: string | null;
  blocked_until: string | null;
  login_methods?: string[];
};

const PAGE_SIZE = 20;
const STATUS_ALL = "__all__";

export default function AdminUsersPage() {
  const [q, setQ] = useSessionState<string>("takt-admin-users-q", "");
  const [status, setStatus] = useSessionState<string>("takt-admin-users-status", "");
  const [page, setPage] = useSessionState<number>("takt-admin-users-page", 1);
  const [sort, setSort] = useSessionState<string>("takt-admin-users-sort", "created_at");
  const [dir, setDir] = useSessionState<SortDir>("takt-admin-users-dir", "desc");

  const { data, isLoading } = useQuery({
    queryKey: ["platform-users", q, status, page, sort, dir],
    queryFn: () => {
      const sp = new URLSearchParams({
        page: String(page),
        page_size: String(PAGE_SIZE),
        sort,
        sort_dir: dir,
      });
      if (q.trim()) sp.set("q", q.trim());
      if (status) sp.set("status", status);
      return api<{ items: UserRow[]; total: number }>(`/api/v1/platform/users?${sp}`);
    },
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
        <h1 className="text-xl font-semibold tracking-tight">Пользователи</h1>
        <p className="mt-1 text-[13px] text-muted">
          Роль платформы, способ входа и активность. Клик по заголовку — сортировка.
        </p>
      </div>
      <div className="flex flex-wrap gap-2">
        <Input
          placeholder="Поиск: имя, email, ID"
          value={q}
          onChange={(e) => {
            setPage(1);
            setQ(e.target.value);
          }}
          className="max-w-sm"
        />
        <Select
          aria-label="Статус"
          value={status || STATUS_ALL}
          onValueChange={(v) => {
            setPage(1);
            setStatus(v === STATUS_ALL ? "" : v);
          }}
          className="h-9 w-[11rem] max-w-full"
          options={[
            { value: STATUS_ALL, label: "Все статусы" },
            { value: "active", label: "Активные" },
            { value: "blocked", label: "Ограниченные" },
            { value: "inactive", label: "Неактивные" },
          ]}
        />
      </div>
      {isLoading ? (
        <p className="text-sm text-muted">Загрузка…</p>
      ) : (
        <div className="overflow-x-auto rounded-[var(--radius)] border border-[var(--border)] bg-white">
          <table className="w-full min-w-[820px] text-left text-[13px]">
            <thead className="border-b border-[var(--border)] text-muted">
              <tr>
                <SortableTh label="Имя" column="name" sort={sort} dir={dir} onSort={onSort} />
                <SortableTh label="Email" column="email" sort={sort} dir={dir} onSort={onSort} />
                <SortableTh label="Роль" column="role" sort={sort} dir={dir} onSort={onSort} />
                <th className="px-3 py-2 font-medium">Вход</th>
                <SortableTh
                  label="Регистрация"
                  column="created_at"
                  sort={sort}
                  dir={dir}
                  onSort={onSort}
                />
                <SortableTh
                  label="Активность"
                  column="last_login_at"
                  sort={sort}
                  dir={dir}
                  onSort={onSort}
                />
              </tr>
            </thead>
            <tbody>
              {(data?.items ?? []).map((u) => (
                <tr key={u.id} className="border-b border-[var(--border)] last:border-0">
                  <td className="px-3 py-2">
                    <Link href={`/admin/users/${u.id}`} className="font-medium text-[var(--accent)]">
                      {u.name}
                    </Link>
                    {!u.is_active || u.blocked_until ? (
                      <span className="ml-2 text-[11px] text-[var(--danger)]">ограничен</span>
                    ) : null}
                  </td>
                  <td className="px-3 py-2 text-muted">{u.email}</td>
                  <td className="px-3 py-2">{platformRoleLabel(u.platform_role)}</td>
                  <td className="px-3 py-2 text-muted">{loginMethodsLabel(u.login_methods)}</td>
                  <td className="px-3 py-2 tabular-nums text-muted">
                    {u.created_at ? new Date(u.created_at).toLocaleDateString("ru-RU") : "—"}
                  </td>
                  <td className="px-3 py-2 tabular-nums text-muted">
                    {u.last_login_at ? new Date(u.last_login_at).toLocaleString("ru-RU") : "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {showPager && (
        <div className="flex items-center gap-2">
          <Button
            type="button"
            variant="secondary"
            size="sm"
            disabled={page <= 1}
            onClick={() => setPage(page - 1)}
          >
            Назад
          </Button>
          <span className="text-[12px] text-muted">
            стр. {page} из {pageCount} · всего {total}
          </span>
          <Button
            type="button"
            variant="secondary"
            size="sm"
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

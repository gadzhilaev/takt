"use client";

import Link from "next/link";
import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import { useSessionState } from "@/lib/use-session-state";
import { loginMethodsLabel, platformRoleLabel } from "@/lib/types";
import { nextSort, type SortDir } from "@/components/admin/sortable-th";
import { DataTable, type DataTableColumn } from "@/components/admin/data-table";
import { useMemo } from "react";

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

  const { data, isLoading, isFetching } = useQuery({
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
    placeholderData: keepPreviousData,
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

  const columns = useMemo<DataTableColumn<UserRow>[]>(
    () => [
      {
        id: "name",
        label: "Имя",
        width: 200,
        sortable: true,
        cell: (u) => (
          <>
            <Link href={`/admin/users/${u.id}`} className="font-medium text-[var(--accent)]">
              {u.name}
            </Link>
            {!u.is_active || u.blocked_until ? (
              <span className="ml-2 text-[11px] text-[var(--danger)]">ограничен</span>
            ) : null}
          </>
        ),
      },
      {
        id: "email",
        label: "Email",
        width: 220,
        sortable: true,
        className: "text-muted",
        cell: (u) => u.email,
      },
      {
        id: "role",
        label: "Роль",
        width: 130,
        sortable: true,
        cell: (u) => platformRoleLabel(u.platform_role),
      },
      {
        id: "login",
        label: "Вход",
        width: 140,
        className: "text-muted",
        cell: (u) => loginMethodsLabel(u.login_methods),
      },
      {
        id: "created_at",
        label: "Регистрация",
        width: 120,
        sortable: true,
        className: "tabular-nums text-muted",
        cell: (u) => (u.created_at ? new Date(u.created_at).toLocaleDateString("ru-RU") : "—"),
      },
      {
        id: "last_login_at",
        label: "Активность",
        width: 160,
        sortable: true,
        className: "tabular-nums text-muted",
        cell: (u) =>
          u.last_login_at ? new Date(u.last_login_at).toLocaleString("ru-RU") : "—",
      },
    ],
    []
  );

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">Пользователи</h1>
        <p className="mt-1 text-[13px] text-muted">
          Сортировка по заголовку · ширину колонки тяните за правый край
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
      {isLoading && !data ? (
        <p className="text-sm text-muted">Загрузка…</p>
      ) : (
        <DataTable
          storageKey="takt-admin-users-cols"
          columns={columns}
          rows={rows}
          rowKey={(u) => u.id}
          sort={sort}
          dir={dir}
          onSort={onSort}
          isFetching={isFetching && !isLoading}
          empty="Пользователи не найдены"
        />
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

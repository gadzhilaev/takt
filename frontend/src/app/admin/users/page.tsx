"use client";

import Link from "next/link";
import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";

type UserRow = {
  id: string;
  name: string;
  email: string;
  platform_role: string;
  is_active: boolean;
  created_at: string | null;
  last_login_at: string | null;
  blocked_until: string | null;
};

export default function AdminUsersPage() {
  const [q, setQ] = useState("");
  const [status, setStatus] = useState("");
  const [page, setPage] = useState(1);
  const { data, isLoading } = useQuery({
    queryKey: ["platform-users", q, status, page],
    queryFn: () => {
      const sp = new URLSearchParams({ page: String(page), page_size: "20" });
      if (q.trim()) sp.set("q", q.trim());
      if (status) sp.set("status", status);
      return api<{ items: UserRow[]; total: number }>(`/api/v1/platform/users?${sp}`);
    },
  });

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold tracking-tight">Пользователи</h1>
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
        <select
          className="h-9 rounded-[var(--radius)] border border-[var(--border)] bg-white px-2 text-[13px]"
          value={status}
          onChange={(e) => {
            setPage(1);
            setStatus(e.target.value);
          }}
        >
          <option value="">Все статусы</option>
          <option value="active">Активные</option>
          <option value="blocked">Ограниченные</option>
          <option value="inactive">Неактивные</option>
        </select>
      </div>
      {isLoading ? (
        <p className="text-sm text-muted">Загрузка…</p>
      ) : (
        <div className="overflow-x-auto rounded-[var(--radius)] border border-[var(--border)] bg-white">
          <table className="w-full min-w-[640px] text-left text-[13px]">
            <thead className="border-b border-[var(--border)] text-muted">
              <tr>
                <th className="px-3 py-2 font-medium">Имя</th>
                <th className="px-3 py-2 font-medium">Email</th>
                <th className="px-3 py-2 font-medium">Роль</th>
                <th className="px-3 py-2 font-medium">Регистрация</th>
                <th className="px-3 py-2 font-medium">Активность</th>
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
                  <td className="px-3 py-2">{u.platform_role}</td>
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
      <div className="flex items-center gap-2">
        <Button type="button" variant="secondary" size="sm" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
          Назад
        </Button>
        <span className="text-[12px] text-muted">
          стр. {page} · всего {data?.total ?? 0}
        </span>
        <Button
          type="button"
          variant="secondary"
          size="sm"
          disabled={(data?.items.length ?? 0) < 20}
          onClick={() => setPage((p) => p + 1)}
        >
          Далее
        </Button>
      </div>
    </div>
  );
}

"use client";

import { useParams } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useState } from "react";
import { loginMethodsLabel, platformRoleLabel } from "@/lib/types";

type UserCard = {
  user: {
    id: string;
    name: string;
    email: string;
    platform_role: string;
    created_at: string | null;
    last_login_at: string | null;
    has_password: boolean;
    is_active: boolean;
    blocked_until: string | null;
    login_methods?: string[];
  };
  identities: { provider: string; email?: string | null }[];
  projects: { id: string; name: string; role: string; is_demo?: boolean }[];
  admin_actions: { id: string; created_at?: string; action: string; details?: string | null }[];
};

export default function AdminUserDetailPage() {
  const { id } = useParams<{ id: string }>();
  const qc = useQueryClient();
  const [reason, setReason] = useState("");
  const { data, isLoading, error } = useQuery({
    queryKey: ["platform-user", id],
    queryFn: () => api<UserCard>(`/api/v1/platform/users/${id}`),
  });

  const block = useMutation({
    mutationFn: () =>
      api(`/api/v1/platform/users/${id}/block`, { method: "POST", json: { reason } }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["platform-user", id] }),
  });
  const unblock = useMutation({
    mutationFn: () => api(`/api/v1/platform/users/${id}/unblock`, { method: "POST" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["platform-user", id] }),
  });

  if (isLoading) return <p className="text-sm text-muted">Загрузка…</p>;
  if (error) return <p className="text-sm text-[var(--danger)]">{(error as Error).message}</p>;
  if (!data) return null;
  const u = data.user;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">{u.name}</h1>
        <p className="text-[13px] text-muted">{u.email}</p>
      </div>
      <dl className="grid gap-3 rounded-[var(--radius)] border border-[var(--border)] bg-white p-4 text-[13px] sm:grid-cols-2">
        <div>
          <dt className="text-muted">ID</dt>
          <dd className="font-mono text-[12px]">{u.id}</dd>
        </div>
        <div>
          <dt className="text-muted">Роль</dt>
          <dd>{platformRoleLabel(u.platform_role)}</dd>
        </div>
        <div>
          <dt className="text-muted">Вход</dt>
          <dd>{loginMethodsLabel(u.login_methods)}</dd>
        </div>
        <div>
          <dt className="text-muted">Регистрация</dt>
          <dd>{u.created_at ? new Date(u.created_at).toLocaleString("ru-RU") : "—"}</dd>
        </div>
        <div>
          <dt className="text-muted">Последняя активность</dt>
          <dd>{u.last_login_at ? new Date(u.last_login_at).toLocaleString("ru-RU") : "—"}</dd>
        </div>
        <div>
          <dt className="text-muted">Пароль</dt>
          <dd>{u.has_password ? "задан" : "только OAuth"}</dd>
        </div>
      </dl>

      <section>
        <h2 className="text-[14px] font-semibold">Способы входа</h2>
        <ul className="mt-2 space-y-1 text-[13px]">
          {data.identities.length === 0 && <li className="text-muted">Нет связанных OAuth</li>}
          {data.identities.map((i) => (
            <li key={i.provider}>
              {i.provider}
              {i.email ? ` · ${i.email}` : ""}
            </li>
          ))}
        </ul>
      </section>

      <section>
        <h2 className="text-[14px] font-semibold">Проекты</h2>
        <ul className="mt-2 space-y-1 text-[13px]">
          {data.projects.map((p) => (
            <li key={p.id}>
              {p.name} · {p.role}
              {p.is_demo ? " · demo" : ""}
            </li>
          ))}
        </ul>
        <p className="mt-2 text-[11px] text-muted">Содержимое задач не отображается.</p>
      </section>

      <section className="space-y-2 rounded-[var(--radius)] border border-[var(--border)] bg-white p-4">
        <h2 className="text-[14px] font-semibold">Ограничение</h2>
        <Input placeholder="Причина" value={reason} onChange={(e) => setReason(e.target.value)} />
        <div className="flex gap-2">
          <Button type="button" disabled={reason.trim().length < 3 || block.isPending} onClick={() => block.mutate()}>
            Заблокировать
          </Button>
          <Button type="button" variant="secondary" disabled={unblock.isPending} onClick={() => unblock.mutate()}>
            Разблокировать
          </Button>
        </div>
      </section>

      <section>
        <h2 className="text-[14px] font-semibold">История админ-действий</h2>
        <ul className="mt-2 space-y-1 text-[12px] text-muted">
          {data.admin_actions.map((a) => (
            <li key={a.id}>
              {a.created_at} · {a.action}
              {a.details ? ` — ${a.details}` : ""}
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}

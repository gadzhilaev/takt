"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
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
    must_change_password?: boolean;
  };
  identities: { provider: string; email?: string | null }[];
  projects: { id: string; name: string; role: string; is_demo?: boolean }[];
  admin_actions: { id: string; created_at?: string; action: string; details?: string | null }[];
};

type PlatformMe = { platform_role: string };

const ROLE_OPTIONS = [
  { value: "none", label: "Пользователь" },
  { value: "support", label: "Поддержка" },
  { value: "moderator", label: "Модератор" },
  { value: "admin", label: "Администратор" },
  { value: "super_admin", label: "Суперадмин" },
];

export default function AdminUserDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const qc = useQueryClient();
  const [reason, setReason] = useState("");
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [isActive, setIsActive] = useState(true);
  const [mustChangePassword, setMustChangePassword] = useState(false);
  const [platformRole, setPlatformRole] = useState("none");
  const [password, setPassword] = useState("");
  const [saveMsg, setSaveMsg] = useState("");

  const { data: me } = useQuery({
    queryKey: ["platform-me"],
    queryFn: () => api<PlatformMe>("/api/v1/platform/me"),
  });
  const isSuper = me?.platform_role === "super_admin";

  const { data, isLoading, error } = useQuery({
    queryKey: ["platform-user", id],
    queryFn: () => api<UserCard>(`/api/v1/platform/users/${id}`),
  });

  useEffect(() => {
    if (!data?.user) return;
    const u = data.user;
    setName(u.name);
    setEmail(u.email);
    setIsActive(u.is_active);
    setMustChangePassword(Boolean(u.must_change_password));
    setPlatformRole(u.platform_role || "none");
    setPassword("");
  }, [data?.user]);

  const save = useMutation({
    mutationFn: () => {
      const json: Record<string, unknown> = {
        name: name.trim(),
        email: email.trim(),
        is_active: isActive,
        must_change_password: mustChangePassword,
      };
      if (password.trim().length >= 8) json.password = password.trim();
      if (isSuper) json.platform_role = platformRole;
      return api<{ user: UserCard["user"] }>(`/api/v1/platform/users/${id}`, {
        method: "PATCH",
        json,
      });
    },
    onSuccess: async () => {
      setPassword("");
      setSaveMsg("Сохранено");
      await qc.invalidateQueries({ queryKey: ["platform-user", id] });
      await qc.invalidateQueries({ queryKey: ["platform-users"] });
      setTimeout(() => setSaveMsg(""), 2000);
    },
  });

  const remove = useMutation({
    mutationFn: () => api(`/api/v1/platform/users/${id}`, { method: "DELETE" }),
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: ["platform-users"] });
      router.push("/admin/users");
    },
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

  const dirty =
    name.trim() !== u.name ||
    email.trim().toLowerCase() !== u.email.toLowerCase() ||
    isActive !== u.is_active ||
    mustChangePassword !== Boolean(u.must_change_password) ||
    (isSuper && platformRole !== (u.platform_role || "none")) ||
    password.trim().length >= 8;

  return (
    <div className="space-y-6">
      <div>
        <Link href="/admin/users" className="text-[13px] text-[var(--accent)]">
          ← К списку
        </Link>
        <h1 className="mt-2 text-xl font-semibold tracking-tight">{u.name}</h1>
        <p className="text-[13px] text-muted">{u.email}</p>
      </div>

      <section className="space-y-3 rounded-[var(--radius)] border border-[var(--border)] bg-white p-4">
        <h2 className="text-[14px] font-semibold">Профиль</h2>
        <div className="grid gap-3 sm:grid-cols-2">
          <label className="block text-[13px]">
            <span className="text-muted">Имя</span>
            <Input className="mt-1" value={name} onChange={(e) => setName(e.target.value)} />
          </label>
          <label className="block text-[13px]">
            <span className="text-muted">Email</span>
            <Input
              className="mt-1"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </label>
          <label className="block text-[13px]">
            <span className="text-muted">Новый пароль</span>
            <Input
              className="mt-1"
              type="password"
              autoComplete="new-password"
              placeholder="Оставьте пустым, чтобы не менять"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
            <span className="mt-1 block text-[11px] text-muted">Минимум 8 символов</span>
          </label>
          {isSuper ? (
            <label className="block text-[13px]">
              <span className="text-muted">Роль платформы</span>
              <Select
                className="mt-1 h-9 w-full"
                value={platformRole}
                onValueChange={setPlatformRole}
                options={ROLE_OPTIONS}
              />
            </label>
          ) : (
            <div className="text-[13px]">
              <p className="text-muted">Роль платформы</p>
              <p className="mt-1 font-medium">{platformRoleLabel(u.platform_role)}</p>
            </div>
          )}
        </div>
        <div className="flex flex-wrap gap-4 text-[13px]">
          <label className="inline-flex items-center gap-2">
            <input
              type="checkbox"
              className="size-4 accent-[var(--accent)]"
              checked={isActive}
              onChange={(e) => setIsActive(e.target.checked)}
            />
            Аккаунт активен
          </label>
          <label className="inline-flex items-center gap-2">
            <input
              type="checkbox"
              className="size-4 accent-[var(--accent)]"
              checked={mustChangePassword}
              onChange={(e) => setMustChangePassword(e.target.checked)}
            />
            Сменить пароль при следующем входе
          </label>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <Button
            type="button"
            disabled={!dirty || save.isPending || name.trim().length < 1 || !email.includes("@")}
            onClick={() => save.mutate()}
          >
            {save.isPending ? "Сохраняем…" : "Сохранить"}
          </Button>
          {saveMsg ? <span className="text-[13px] text-muted">{saveMsg}</span> : null}
          {save.isError ? (
            <span className="text-[13px] text-[var(--danger)]">{(save.error as Error).message}</span>
          ) : null}
        </div>
      </section>

      <dl className="grid gap-3 rounded-[var(--radius)] border border-[var(--border)] bg-white p-4 text-[13px] sm:grid-cols-2">
        <div>
          <dt className="text-muted">ID</dt>
          <dd className="font-mono text-[12px]">{u.id}</dd>
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
          {data.projects.length === 0 && <li className="text-muted">Не состоит в проектах</li>}
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
          <Button
            type="button"
            disabled={reason.trim().length < 3 || block.isPending}
            onClick={() => block.mutate()}
          >
            Заблокировать
          </Button>
          <Button
            type="button"
            variant="secondary"
            disabled={unblock.isPending}
            onClick={() => unblock.mutate()}
          >
            Разблокировать
          </Button>
        </div>
      </section>

      <section className="space-y-2 rounded-[var(--radius)] border border-[var(--danger)]/30 bg-white p-4">
        <h2 className="text-[14px] font-semibold text-[var(--danger)]">Удаление</h2>
        <p className="text-[13px] text-muted">
          Аккаунт удаляется безвозвратно. Задачи пользователя переназначаются на вас как автора;
          членства и сессии снимаются.
        </p>
        <Button
          type="button"
          variant="secondary"
          disabled={remove.isPending}
          onClick={() => {
            const ok = window.confirm(
              `Удалить пользователя «${u.name}» (${u.email})? Это действие нельзя отменить.`
            );
            if (ok) remove.mutate();
          }}
        >
          {remove.isPending ? "Удаляем…" : "Удалить пользователя"}
        </Button>
        {remove.isError ? (
          <p className="text-[13px] text-[var(--danger)]">{(remove.error as Error).message}</p>
        ) : null}
      </section>

      <section>
        <h2 className="text-[14px] font-semibold">История админ-действий</h2>
        <ul className="mt-2 space-y-1 text-[12px] text-muted">
          {data.admin_actions.length === 0 && <li>Пока пусто</li>}
          {data.admin_actions.map((a) => (
            <li key={a.id}>
              {a.created_at ? new Date(a.created_at).toLocaleString("ru-RU") : "—"} · {a.action}
              {a.details ? ` — ${a.details}` : ""}
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}

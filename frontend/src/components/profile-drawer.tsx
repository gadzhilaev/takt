"use client";

import { AppIcon } from "@/components/ui/app-icon";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { api } from "@/lib/api";
import { hasPlatformAccess, platformRoleLabel, type User } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { UserAvatar } from "@/components/user-avatar";
import { disableWebPush, enableWebPush, getPushStatus } from "@/lib/web-push";
import { OAuthButtons } from "@/components/oauth/oauth-buttons";
import Link from "next/link";

export function ProfileDrawer({
  open,
  onClose,
  user,
  onOpenNotifications,
}: {
  open: boolean;
  onClose: () => void;
  user: User;
  onOpenNotifications?: () => void;
}) {
  const qc = useQueryClient();
  const router = useRouter();
  const fileRef = useRef<HTMLInputElement>(null);
  const [name, setName] = useState(user.name);
  const [email, setEmail] = useState(user.email);
  const [msg, setMsg] = useState("");
  const [err, setErr] = useState("");
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [passwordCode, setPasswordCode] = useState("");
  const [passwordStep, setPasswordStep] = useState<"form" | "code">("form");
  const [pushMsg, setPushMsg] = useState("");
  const [pushBusy, setPushBusy] = useState(false);
  const [pushState, setPushState] = useState<Awaited<ReturnType<typeof getPushStatus>> | null>(null);

  const notificationsQuery = useQuery({
    queryKey: ["notifications"],
    enabled: open,
    queryFn: () =>
      api<{ items: { id: string }[]; unread: number }>("/api/v1/notifications?page_size=20"),
    refetchInterval: open ? 30_000 : false,
  });

  useEffect(() => {
    if (open) {
      setName(user.name);
      setEmail(user.email);
      setMsg("");
      setErr("");
      setPushMsg("");
      setPasswordStep("form");
      setPasswordCode("");
      setCurrentPassword("");
      setNewPassword("");
      getPushStatus().then(setPushState).catch(() => null);
    }
  }, [open, user]);

  useEffect(() => {
    if (!open) return;
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  const saveProfile = useMutation({
    mutationFn: () => api<{ user: User }>("/api/v1/users/me", { method: "PATCH", json: { name, email } }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["me"] });
      setMsg("Профиль сохранён");
      setErr("");
    },
    onError: (e: Error) => setErr(e.message),
  });

  const sendPasswordCode = useMutation({
    mutationFn: () =>
      api("/api/v1/auth/change-password/send-code", {
        method: "POST",
        json: { current_password: currentPassword, new_password: newPassword },
      }),
    onSuccess: () => {
      setErr("");
      setMsg("Код отправлен на email");
      setPasswordStep("code");
    },
    onError: (e: Error) => setErr(e.message),
  });

  const confirmPasswordCode = useMutation({
    mutationFn: () =>
      api("/api/v1/auth/change-password/confirm", {
        method: "POST",
        json: { code: passwordCode.trim() },
      }),
    onSuccess: async () => {
      setMsg("Пароль изменён. Войдите снова");
      await api("/api/v1/auth/logout", { method: "POST" }).catch(() => null);
      router.push("/login");
    },
    onError: (e: Error) => setErr(e.message),
  });

  async function onAvatar(file: File | null) {
    setErr("");
    if (!file) {
      await api("/api/v1/users/me/avatar", { method: "DELETE" });
      qc.invalidateQueries({ queryKey: ["me"] });
      setMsg("Аватар удалён");
      return;
    }
    const fd = new FormData();
    fd.append("file", file);
    const token = document.cookie.match(/(?:^|; )csrf_token=([^;]+)/)?.[1];
    const res = await fetch("/api/v1/users/me/avatar", {
      method: "POST",
      credentials: "include",
      headers: token ? { "X-CSRF-Token": decodeURIComponent(token) } : undefined,
      body: fd,
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setErr(body?.error?.message || "Не удалось загрузить аватар");
      return;
    }
    qc.invalidateQueries({ queryKey: ["me"] });
    setMsg("Аватар обновлён");
  }

  async function logout() {
    await api("/api/v1/auth/logout", { method: "POST" });
    router.push("/");
  }

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[60] flex justify-end">
      <button type="button" className="absolute inset-0 bg-black/25" aria-label="Закрыть" onClick={onClose} />
      <aside
        className="relative z-10 flex h-full w-full max-w-md flex-col border-l border-hairline bg-[var(--surface)] shadow-sm"
        role="dialog"
        aria-label="Мой профиль"
      >
        <div className="flex items-center justify-between border-b border-hairline px-4 py-3">
          <h2 className="text-base font-semibold">Мой профиль</h2>
          <button type="button" className="rounded p-1.5 text-muted hover:bg-[var(--surface-2)]" onClick={onClose} aria-label="Закрыть">
            <AppIcon name="close" size={16} />
          </button>
        </div>

        <div className="flex-1 space-y-5 overflow-y-auto p-4">
          <div className="flex flex-col items-center gap-3 pt-2">
            <button
              type="button"
              className="group relative rounded-full focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--ring)]"
              onClick={() => fileRef.current?.click()}
              aria-label="Изменить аватар"
            >
              <UserAvatar name={user.name} avatarUrl={user.avatar_url} size={28} />
              <span className="absolute inset-0 flex items-center justify-center rounded-full bg-black/45 text-white opacity-0 transition-opacity group-hover:opacity-100 group-focus-visible:opacity-100">
                <span className="flex flex-col items-center gap-1 text-[12px] font-medium">
                  <AppIcon name="camera" size={20} />
                  Изменить
                </span>
              </span>
            </button>
            <input
              ref={fileRef}
              type="file"
              accept="image/jpeg,image/png,image/webp,image/gif"
              className="hidden"
              onChange={(e) => onAvatar(e.target.files?.[0] ?? null)}
            />
            {user.avatar_url && (
              <button
                type="button"
                className="text-sm text-muted hover:text-foreground"
                onClick={() => onAvatar(null)}
              >
                Удалить фото
              </button>
            )}
          </div>

          <form
            className="space-y-3"
            onSubmit={(e) => {
              e.preventDefault();
              saveProfile.mutate();
            }}
          >
            <div>
              <label className="label-text" htmlFor="profile-name">
                Имя
              </label>
              <Input id="profile-name" value={name} onChange={(e) => setName(e.target.value)} />
            </div>
            <div>
              <label className="label-text" htmlFor="profile-email">
                Email
              </label>
              <Input id="profile-email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
            </div>
            <Button type="submit" size="sm" disabled={saveProfile.isPending}>
              Сохранить
            </Button>
          </form>

          {hasPlatformAccess(user.platform_role) && (
            <div className="rounded-[var(--radius)] border border-[var(--border)] bg-[var(--surface-2)] p-3">
              <p className="text-[12px] font-medium text-muted">Роль платформы</p>
              <p className="mt-0.5 text-[14px] font-semibold text-[var(--foreground)]">
                {platformRoleLabel(user.platform_role)}
              </p>
              <Link
                href="/admin"
                onClick={onClose}
                className="mt-2 inline-flex text-[13px] font-semibold text-[var(--accent)] hover:underline"
              >
                Открыть панель администратора
              </Link>
            </div>
          )}

          <div className="border-t border-hairline pt-4">
            <p className="mb-2 flex items-center gap-1.5 text-sm font-semibold">
              <AppIcon name="notifications" size={16} /> Уведомления
            </p>
            <div className="space-y-2">
              <Button
                type="button"
                size="sm"
                variant="secondary"
                className="w-full justify-start"
                onClick={() => {
                  if (onOpenNotifications) onOpenNotifications();
                  else {
                    onClose();
                    router.push("/app/inbox");
                  }
                }}
              >
                Открыть все уведомления
                {(notificationsQuery.data?.unread ?? 0) > 0
                  ? ` · ${notificationsQuery.data?.unread}`
                  : ""}
              </Button>
              {pushState?.supported && (
                <Button
                  type="button"
                  size="sm"
                  variant="ghost"
                  className="w-full justify-start"
                  disabled={pushBusy || pushState.configured === false}
                  onClick={async () => {
                    setPushBusy(true);
                    setPushMsg("");
                    try {
                      if (pushState.subscribed) {
                        await disableWebPush();
                        setPushMsg("Браузерные уведомления отключены");
                      } else {
                        const res = await enableWebPush();
                        setPushMsg(res.message);
                      }
                      setPushState(await getPushStatus());
                    } catch (e) {
                      setPushMsg((e as Error).message || "Не удалось изменить уведомления");
                    } finally {
                      setPushBusy(false);
                    }
                  }}
                >
                  {pushState.subscribed
                    ? "Отключить браузерный push"
                    : pushState.configured
                      ? "Включить браузерный push"
                      : "Браузерный push недоступен"}
                </Button>
              )}
              {pushMsg && <p className="text-xs text-muted">{pushMsg}</p>}
            </div>
          </div>

          <div className="border-t border-hairline pt-4">
            <p className="mb-2 text-sm font-semibold">Смена пароля</p>
            {passwordStep === "form" ? (
              <form
                className="space-y-3"
                onSubmit={(e) => {
                  e.preventDefault();
                  sendPasswordCode.mutate();
                }}
              >
                <div>
                  <label className="label-text" htmlFor="cur-pass">
                    Текущий пароль
                  </label>
                  <Input
                    id="cur-pass"
                    type="password"
                    autoComplete="current-password"
                    value={currentPassword}
                    onChange={(e) => setCurrentPassword(e.target.value)}
                  />
                </div>
                <div>
                  <label className="label-text" htmlFor="new-pass">
                    Новый пароль
                  </label>
                  <Input
                    id="new-pass"
                    type="password"
                    autoComplete="new-password"
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                  />
                </div>
                <Button
                  type="submit"
                  size="sm"
                  variant="secondary"
                  disabled={sendPasswordCode.isPending || newPassword.length < 8}
                >
                  Получить код на email
                </Button>
              </form>
            ) : (
              <form
                className="space-y-3"
                onSubmit={(e) => {
                  e.preventDefault();
                  confirmPasswordCode.mutate();
                }}
              >
                <p className="text-xs text-muted">Код отправлен на {user.email}</p>
                <div>
                  <label className="label-text" htmlFor="pwd-code">
                    Код из письма
                  </label>
                  <Input
                    id="pwd-code"
                    inputMode="numeric"
                    autoComplete="one-time-code"
                    value={passwordCode}
                    onChange={(e) => setPasswordCode(e.target.value)}
                    placeholder="6 цифр"
                  />
                </div>
                <Button
                  type="submit"
                  size="sm"
                  variant="secondary"
                  disabled={confirmPasswordCode.isPending || passwordCode.trim().length < 4}
                >
                  Подтвердить и сменить
                </Button>
                <Button
                  type="button"
                  size="sm"
                  variant="ghost"
                  disabled={sendPasswordCode.isPending}
                  onClick={() => sendPasswordCode.mutate()}
                >
                  Отправить код ещё раз
                </Button>
              </form>
            )}
          </div>

          <LinkedAccountsSection />

          {msg && <p className="text-sm text-[var(--success)]">{msg}</p>}
          {err && <p className="text-sm text-[var(--danger)]">{err}</p>}
        </div>

        <div className="border-t border-hairline p-3">
          <Button variant="ghost" className="w-full justify-start" onClick={logout}>
            <AppIcon name="logout" size={16} /> Выйти
          </Button>
        </div>
      </aside>
    </div>
  );
}

function LinkedAccountsSection() {
  const qc = useQueryClient();
  const { data } = useQuery({
    queryKey: ["oauth-identities"],
    queryFn: () =>
      api<{ items: { id: string; provider: string; email: string | null }[]; has_password: boolean }>(
        "/api/v1/auth/oauth/identities"
      ),
  });
  const unlink = useMutation({
    mutationFn: (id: string) => api(`/api/v1/auth/oauth/identities/${id}`, { method: "DELETE" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["oauth-identities"] }),
  });

  return (
    <div className="space-y-2 border-t border-hairline pt-4">
      <p className="text-[13px] font-semibold">Связанные аккаунты</p>
      <ul className="space-y-1 text-[13px]">
        {(data?.items ?? []).map((i) => (
          <li key={i.id} className="flex items-center justify-between gap-2">
            <span>
              {i.provider}
              {i.email ? ` · ${i.email}` : ""}
            </span>
            <Button
              type="button"
              size="sm"
              variant="ghost"
              disabled={unlink.isPending}
              onClick={() => {
                if (window.confirm(`Отвязать ${i.provider}?`)) unlink.mutate(i.id);
              }}
            >
              Отвязать
            </Button>
          </li>
        ))}
        {(data?.items ?? []).length === 0 && <li className="text-muted">Пока нет OAuth-привязок</li>}
      </ul>
      {!data?.has_password && (
        <p className="text-[11px] text-muted">Задайте пароль, прежде чем отвязывать последний способ входа.</p>
      )}
      <OAuthButtons mode="link" />
    </div>
  );
}

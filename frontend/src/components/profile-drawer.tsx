"use client";

import { AccountDeletePreview } from "@/components/account-delete-preview";
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
import { SignInMethodsSection } from "@/components/sign-in-methods";
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
  const [pushMsg, setPushMsg] = useState("");
  const [pushBusy, setPushBusy] = useState(false);
  const [pushState, setPushState] = useState<Awaited<ReturnType<typeof getPushStatus>> | null>(null);
  const [deleteConfirm, setDeleteConfirm] = useState("");
  const [deleteBusy, setDeleteBusy] = useState(false);
  const [showDelete, setShowDelete] = useState(false);

  const notificationsQuery = useQuery({
    queryKey: ["notifications"],
    enabled: open,
    queryFn: () =>
      api<{ items: { id: string }[]; unread: number }>("/api/v1/notifications?page_size=20"),
    refetchInterval: open ? 30_000 : false,
  });
  const sessionsQuery = useQuery({
    queryKey: ["account-sessions"], enabled: open,
    queryFn: () => api<{ items: { id: string; label: string; created_at: string; last_activity_at: string; is_current: boolean }[] }>("/api/v1/auth/sessions"),
  });
  const pushDevicesQuery = useQuery({
    queryKey: ["push-devices"], enabled: open,
    queryFn: () => api<{ items: { id: string; kind: "browser" | "app"; label: string; app_version?: string | null; created_at: string; last_activity_at: string }[] }>("/api/v1/notifications/devices"),
  });

  function formatDeviceDate(value: string) {
    return new Intl.DateTimeFormat("ru-RU", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value));
  }
  async function revokeSession(id: string) {
    await api(`/api/v1/auth/sessions/${id}`, { method: "DELETE" });
    await sessionsQuery.refetch();
  }
  async function revokePushDevice(kind: "browser" | "app", id: string) {
    await api(`/api/v1/notifications/devices/${kind}/${id}`, { method: "DELETE" });
    await pushDevicesQuery.refetch();
    setPushState(await getPushStatus().catch(() => null));
  }

  useEffect(() => {
    if (open) {
      setName(user.name);
      setEmail(user.email);
      setMsg("");
      setErr("");
      setPushMsg("");
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
      const detail = body?.detail?.error?.message || body?.error?.message;
      setErr(typeof detail === "string" ? detail : "");
      return;
    }
    qc.invalidateQueries({ queryKey: ["me"] });
    setMsg("Аватар обновлён");
  }

  async function deleteAccount() {
    setErr("");
    setMsg("");
    if (deleteConfirm.trim().toUpperCase() !== "УДАЛИТЬ") {
      setErr("Введите УДАЛИТЬ для подтверждения");
      return;
    }
    setDeleteBusy(true);
    try {
      await api("/api/v1/users/me", { method: "DELETE" });
      qc.clear();
      router.replace("/login");
      onClose();
    } catch (e) {
      setErr((e as Error).message || "Не удалось удалить аккаунт");
    } finally {
      setDeleteBusy(false);
    }
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
              className="group relative rounded-full focus-visible:outline-none"
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
                      setPushMsg((e as Error).message || "");
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

          <section className="border-t border-hairline pt-4">
            <h3 className="text-sm font-semibold">Сеансы входа</h3>
            <p className="mb-2 mt-1 text-xs text-muted">Браузеры и устройства, где открыт аккаунт.</p>
            <div className="space-y-2">
              {sessionsQuery.isLoading && <p className="text-xs text-muted">Загрузка…</p>}
              {sessionsQuery.data?.items.map((session) => (
                <div key={session.id} className="flex items-start justify-between gap-3 rounded-md border border-hairline p-3">
                  <div className="min-w-0">
                    <p className="text-sm font-medium">{session.label}{session.is_current ? " · это устройство" : ""}</p>
                    <p className="mt-1 text-xs text-muted">Активность: {formatDeviceDate(session.last_activity_at)}</p>
                  </div>
                  <button type="button" className="shrink-0 text-xs font-medium text-[var(--danger)] hover:underline" onClick={() => revokeSession(session.id).catch((e) => setErr((e as Error).message))}>Завершить</button>
                </div>
              ))}
              {!sessionsQuery.isLoading && !sessionsQuery.data?.items.length && <p className="text-xs text-muted">Активных сеансов нет.</p>}
            </div>
          </section>
          <section className="border-t border-hairline pt-4">
            <h3 className="text-sm font-semibold">Получатели push</h3>
            <p className="mb-2 mt-1 text-xs text-muted">Регистрации браузеров и приложения.</p>
            <div className="space-y-2">
              {pushDevicesQuery.isLoading && <p className="text-xs text-muted">Загрузка…</p>}
              {pushDevicesQuery.data?.items.map((device) => (
                <div key={`${device.kind}:${device.id}`} className="flex items-start justify-between gap-3 rounded-md border border-hairline p-3">
                  <div className="min-w-0">
                    <p className="text-sm font-medium">{device.label}{device.app_version ? ` · ${device.app_version}` : ""}</p>
                    <p className="mt-1 text-xs text-muted">Активность: {formatDeviceDate(device.last_activity_at)}</p>
                  </div>
                  <button type="button" className="shrink-0 text-xs font-medium text-[var(--danger)] hover:underline" onClick={() => revokePushDevice(device.kind, device.id).catch((e) => setErr((e as Error).message))}>Отключить</button>
                </div>
              ))}
              {!pushDevicesQuery.isLoading && !pushDevicesQuery.data?.items.length && <p className="text-xs text-muted">Push-устройства не подключены.</p>}
            </div>
          </section>

          <SignInMethodsSection
            onMessage={(m) => {
              setMsg(m);
              setErr("");
            }}
            onError={(m) => {
              setErr(m);
              if (m) setMsg("");
            }}
          />

          {msg && <p className="text-sm text-[var(--success)]">{msg}</p>}
          {err && <p className="text-sm text-[var(--danger)]">{err}</p>}
        </div>

        <div className="space-y-2 border-t border-hairline p-3">
          <Button variant="ghost" className="w-full justify-start" onClick={logout}>
            <AppIcon name="logout" size={16} /> Выйти
          </Button>
          {!showDelete ? (
            <Button
              variant="ghost"
              className="w-full justify-start text-[var(--danger)]"
              onClick={() => setShowDelete(true)}
            >
              Удалить аккаунт
            </Button>
          ) : (
            <div className="space-y-2 rounded-md border border-hairline p-3">
              <p className="text-xs text-muted">
                Необратимо. Профиль обезличится, сессии и уведомления отключатся.
              </p>
              <AccountDeletePreview />
              <p className="text-xs text-muted">Для подтверждения введите УДАЛИТЬ.</p>
              <Input
                value={deleteConfirm}
                onChange={(e) => setDeleteConfirm(e.target.value)}
                placeholder="УДАЛИТЬ"
                autoComplete="off"
                disabled={deleteBusy}
              />
              <div className="flex gap-2">
                <Button
                  variant="destructive"
                  className="flex-1"
                  disabled={deleteBusy}
                  onClick={deleteAccount}
                >
                  {deleteBusy ? "…" : "Удалить"}
                </Button>
                <Button
                  variant="ghost"
                  className="flex-1"
                  disabled={deleteBusy}
                  onClick={() => {
                    setShowDelete(false);
                    setDeleteConfirm("");
                  }}
                >
                  Отмена
                </Button>
              </div>
              <Link href="/account-delete" className="text-xs text-muted underline-offset-2 hover:underline">
                Страница удаления для магазинов
              </Link>
            </div>
          )}
        </div>
      </aside>
    </div>
  );
}


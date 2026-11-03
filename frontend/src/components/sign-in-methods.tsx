"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { PasswordInput } from "@/components/ui/password-input";
import { AppIcon } from "@/components/ui/app-icon";
import { useOAuthProviders } from "@/components/oauth/oauth-buttons";
import { cn } from "@/lib/utils";
import type { User } from "@/lib/types";

type Identity = { id: string; provider: string; email: string | null };
type IdentitiesResponse = { items: Identity[]; has_password: boolean };

const WEB_PROVIDERS = ["vk", "yandex"] as const;

const PROVIDER_META: Record<string, { label: string; icon: string }> = {
  vk: { label: "VK ID", icon: "/brand/oauth-vk.svg" },
  yandex: { label: "Яндекс ID", icon: "/brand/oauth-yandex.svg" },
};

function providerLabel(id: string) {
  return PROVIDER_META[id]?.label ?? id;
}

/** Блок «Вход и безопасность»: пароль + привязки VK/Яндекс в одном списке. */
export function SignInMethodsSection({
  className,
  onMessage,
  onError,
}: {
  className?: string;
  onMessage?: (msg: string) => void;
  onError?: (msg: string) => void;
}) {
  const qc = useQueryClient();
  const router = useRouter();
  const { data: providersMeta } = useOAuthProviders();
  const { data: meData } = useQuery({
    queryKey: ["me"],
    queryFn: () => api<{ user: User }>("/api/v1/auth/me"),
    staleTime: 60_000,
  });
  const { data, isLoading } = useQuery({
    queryKey: ["oauth-identities"],
    queryFn: () => api<IdentitiesResponse>("/api/v1/auth/oauth/identities"),
  });

  const [pwdOpen, setPwdOpen] = useState(false);
  const [passwordStep, setPasswordStep] = useState<"form" | "code">("form");
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [newPasswordConfirm, setNewPasswordConfirm] = useState("");
  const [passwordCode, setPasswordCode] = useState("");
  const [busyProvider, setBusyProvider] = useState<string | null>(null);

  const linkedByProvider = new Map((data?.items ?? []).map((i) => [i.provider, i]));
  const hasPassword = Boolean(data?.has_password);
  const enabledProviders = WEB_PROVIDERS.filter((id) => providersMeta?.providers?.[id]?.enabled);
  const email = meData?.user?.email?.trim() ?? "";

  const unlink = useMutation({
    mutationFn: (id: string) => api(`/api/v1/auth/oauth/identities/${id}`, { method: "DELETE" }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["oauth-identities"] });
      onMessage?.("Способ входа отвязан");
    },
    onError: (e: Error) => onError?.(e.message),
  });

  const sendChangeCode = useMutation({
    mutationFn: () =>
      api("/api/v1/auth/change-password/send-code", {
        method: "POST",
        json: { current_password: currentPassword, new_password: newPassword },
      }),
    onSuccess: () => {
      onMessage?.("Код отправлен на email");
      setPasswordStep("code");
    },
    onError: (e: Error) => onError?.(e.message),
  });

  const confirmChangeCode = useMutation({
    mutationFn: () =>
      api("/api/v1/auth/change-password/confirm", {
        method: "POST",
        json: { code: passwordCode.trim() },
      }),
    onSuccess: async () => {
      onMessage?.("Пароль обновлён. Войдите снова");
      await api("/api/v1/auth/logout", { method: "POST" }).catch(() => null);
      router.push("/login");
    },
    onError: (e: Error) => onError?.(e.message),
  });

  const sendSetCode = useMutation({
    mutationFn: () =>
      api("/api/v1/auth/forgot-password/send-code", {
        method: "POST",
        json: { email },
      }),
    onSuccess: () => {
      onMessage?.("Код отправлен на email");
      setPasswordStep("code");
    },
    onError: (e: Error) => onError?.(e.message),
  });

  const confirmSetCode = useMutation({
    mutationFn: () =>
      api<{ message?: string }>("/api/v1/auth/forgot-password/confirm", {
        method: "POST",
        json: {
          email,
          code: passwordCode.trim(),
          new_password: newPassword,
          new_password_confirm: newPasswordConfirm,
        },
      }),
    onSuccess: async (res) => {
      onMessage?.(res.message || "Пароль задан. Войдите снова");
      await api("/api/v1/auth/logout", { method: "POST" }).catch(() => null);
      const msg = res.message || "Пароль задан. Войдите с новым паролем.";
      router.push(`/login?message=${encodeURIComponent(msg)}`);
    },
    onError: (e: Error) => onError?.(e.message),
  });

  function openPasswordPanel() {
    setPwdOpen((v) => !v);
    setPasswordStep("form");
    setPasswordCode("");
    setCurrentPassword("");
    setNewPassword("");
    setNewPasswordConfirm("");
    onError?.("");
  }

  async function linkProvider(provider: string) {
    setBusyProvider(provider);
    onError?.("");
    try {
      const qs = new URLSearchParams({ client: "web", link: "true" });
      const res = await api<{ authorize_url: string }>(
        `/api/v1/auth/oauth/${provider}/start?${qs.toString()}`
      );
      window.location.href = res.authorize_url;
    } catch (e) {
      onError?.(e instanceof Error ? e.message : "Не удалось начать привязку");
      setBusyProvider(null);
    }
  }

  const setPasswordValid =
    newPassword.length >= 8 && newPassword === newPasswordConfirm && Boolean(email);

  return (
    <div className={cn("space-y-3 border-t border-hairline pt-4", className)}>
      <div>
        <p className="text-[13px] font-semibold tracking-tight">Вход и безопасность</p>
        <p className="mt-0.5 text-[12px] leading-snug text-muted">
          Пароль и сервисы можно использовать вместе.
        </p>
      </div>

      <div className="overflow-hidden rounded-[var(--radius)] border border-[var(--border)] bg-[var(--surface)]">
        {/* Password row */}
        <div className="flex items-center gap-3 px-3 py-2.5">
          <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-[var(--surface-2)] text-[var(--muted)]">
            <AppIcon name="lock" size={16} />
          </span>
          <div className="min-w-0 flex-1">
            <p className="text-[13px] font-medium leading-tight">Email и пароль</p>
            <p className="text-[11px] text-muted">
              {isLoading ? "…" : hasPassword ? "Задан" : "Не задан"}
            </p>
          </div>
          <Button
            type="button"
            size="sm"
            variant="secondary"
            className="shrink-0 rounded-full px-3"
            onClick={openPasswordPanel}
          >
            {hasPassword ? "Сменить" : "Задать"}
          </Button>
        </div>

        {pwdOpen && (
          <div className="space-y-2.5 border-t border-hairline bg-[var(--surface-2)] px-3 py-3">
            {hasPassword ? (
              passwordStep === "form" ? (
                <>
                  <div>
                    <label className="label-text" htmlFor="signin-cur-pass">
                      Текущий пароль
                    </label>
                    <PasswordInput
                      id="signin-cur-pass"
                      autoComplete="current-password"
                      value={currentPassword}
                      onChange={(e) => setCurrentPassword(e.target.value)}
                    />
                  </div>
                  <div>
                    <label className="label-text" htmlFor="signin-new-pass">
                      Новый пароль
                    </label>
                    <PasswordInput
                      id="signin-new-pass"
                      autoComplete="new-password"
                      value={newPassword}
                      onChange={(e) => setNewPassword(e.target.value)}
                    />
                  </div>
                  <Button
                    type="button"
                    size="sm"
                    className="rounded-full"
                    disabled={sendChangeCode.isPending || newPassword.length < 8 || !currentPassword}
                    onClick={() => sendChangeCode.mutate()}
                  >
                    Получить код на email
                  </Button>
                </>
              ) : (
                <>
                  <p className="text-[12px] text-muted">Введите код из письма</p>
                  <Input
                    inputMode="numeric"
                    autoComplete="one-time-code"
                    value={passwordCode}
                    onChange={(e) => setPasswordCode(e.target.value)}
                    placeholder="6 цифр"
                  />
                  <div className="flex flex-wrap gap-2">
                    <Button
                      type="button"
                      size="sm"
                      className="rounded-full"
                      disabled={confirmChangeCode.isPending || passwordCode.trim().length < 4}
                      onClick={() => confirmChangeCode.mutate()}
                    >
                      Подтвердить
                    </Button>
                    <Button
                      type="button"
                      size="sm"
                      variant="ghost"
                      disabled={sendChangeCode.isPending}
                      onClick={() => sendChangeCode.mutate()}
                    >
                      Отправить снова
                    </Button>
                  </div>
                </>
              )
            ) : passwordStep === "form" ? (
              <>
                <p className="text-[12px] text-muted">
                  Пришлём код на {email || "email"} — после подтверждения зададите пароль для входа.
                </p>
                <Button
                  type="button"
                  size="sm"
                  className="rounded-full"
                  disabled={sendSetCode.isPending || !email}
                  onClick={() => sendSetCode.mutate()}
                >
                  Отправить код
                </Button>
              </>
            ) : (
              <>
                <p className="text-[12px] text-muted">Код из письма на {email}</p>
                <Input
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  value={passwordCode}
                  onChange={(e) => setPasswordCode(e.target.value)}
                  placeholder="6 цифр"
                />
                <div>
                  <label className="label-text" htmlFor="signin-set-pass">
                    Новый пароль
                  </label>
                  <PasswordInput
                    id="signin-set-pass"
                    autoComplete="new-password"
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                  />
                </div>
                <div>
                  <label className="label-text" htmlFor="signin-set-pass-2">
                    Повтор пароля
                  </label>
                  <PasswordInput
                    id="signin-set-pass-2"
                    autoComplete="new-password"
                    value={newPasswordConfirm}
                    onChange={(e) => setNewPasswordConfirm(e.target.value)}
                  />
                </div>
                <div className="flex flex-wrap gap-2">
                  <Button
                    type="button"
                    size="sm"
                    className="rounded-full"
                    disabled={
                      confirmSetCode.isPending ||
                      passwordCode.trim().length < 4 ||
                      !setPasswordValid
                    }
                    onClick={() => confirmSetCode.mutate()}
                  >
                    Задать пароль
                  </Button>
                  <Button
                    type="button"
                    size="sm"
                    variant="ghost"
                    disabled={sendSetCode.isPending}
                    onClick={() => sendSetCode.mutate()}
                  >
                    Отправить снова
                  </Button>
                </div>
              </>
            )}
          </div>
        )}

        {/* OAuth rows */}
        {enabledProviders.map((id) => {
          const linked = linkedByProvider.get(id);
          const meta = PROVIDER_META[id];
          return (
            <div
              key={id}
              className="flex items-center gap-3 border-t border-hairline px-3 py-2.5"
            >
              <span className="flex size-9 shrink-0 items-center justify-center overflow-hidden rounded-full bg-[var(--surface-2)]">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={`${meta.icon}?v=2`}
                  alt=""
                  width={20}
                  height={20}
                  className="size-5 object-contain"
                />
              </span>
              <div className="min-w-0 flex-1">
                <p className="text-[13px] font-medium leading-tight">{providerLabel(id)}</p>
                <p className="truncate text-[11px] text-muted">
                  {linked
                    ? linked.email
                      ? `Привязан · ${linked.email}`
                      : "Привязан"
                    : "Не привязан"}
                </p>
              </div>
              {linked ? (
                <Button
                  type="button"
                  size="sm"
                  variant="ghost"
                  className="shrink-0 rounded-full px-3 text-[var(--danger)]"
                  disabled={unlink.isPending}
                  onClick={() => {
                    if (window.confirm(`Отвязать ${providerLabel(id)}?`)) {
                      unlink.mutate(linked.id);
                    }
                  }}
                >
                  Отвязать
                </Button>
              ) : (
                <Button
                  type="button"
                  size="sm"
                  variant="secondary"
                  className="shrink-0 rounded-full px-3"
                  disabled={busyProvider !== null}
                  onClick={() => linkProvider(id)}
                >
                  {busyProvider === id ? "…" : "Привязать"}
                </Button>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

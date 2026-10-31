"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";

type MethodFlags = {
  apple: boolean;
  vk: boolean;
  yandex: boolean;
  email_password: boolean;
};

type Privacy = { url: string; text: string };
type Support = { email: string; url: string; telegram: string };

type SettingsResponse = {
  stored: Record<string, unknown>;
  oauth_providers: {
    providers?: Record<
      string,
      {
        enabled: boolean;
        configured: boolean;
        admin_enabled?: boolean;
        policy_blocked?: boolean;
        label?: string;
      }
    >;
    notes?: string[];
  };
  oauth_login_methods?: MethodFlags;
  privacy_policy?: Privacy;
  support?: Support;
};

const LABELS: { key: keyof MethodFlags; title: string; hint: string }[] = [
  { key: "email_password", title: "Email и пароль", hint: "Обычная регистрация и вход" },
  { key: "vk", title: "VK ID", hint: "Кнопка на сайте и в приложении" },
  { key: "yandex", title: "Яндекс ID", hint: "Кнопка на сайте и в приложении" },
  { key: "apple", title: "Apple", hint: "Нужны credentials; на РФ может быть политика" },
];

const DEFAULT_FLAGS: MethodFlags = {
  apple: true,
  vk: true,
  yandex: true,
  email_password: true,
};

const EMPTY_PRIVACY: Privacy = { url: "", text: "" };
const EMPTY_SUPPORT: Support = { email: "", url: "", telegram: "" };

export default function AdminSettingsPage() {
  const qc = useQueryClient();
  const { data, isLoading, error } = useQuery({
    queryKey: ["platform-settings"],
    queryFn: () => api<SettingsResponse>("/api/v1/platform/settings"),
  });
  const [flags, setFlags] = useState<MethodFlags>(DEFAULT_FLAGS);
  const [privacy, setPrivacy] = useState<Privacy>(EMPTY_PRIVACY);
  const [support, setSupport] = useState<Support>(EMPTY_SUPPORT);
  const [savedMsg, setSavedMsg] = useState("");

  useEffect(() => {
    if (data?.oauth_login_methods) setFlags({ ...DEFAULT_FLAGS, ...data.oauth_login_methods });
    if (data?.privacy_policy) setPrivacy({ ...EMPTY_PRIVACY, ...data.privacy_policy });
    if (data?.support) setSupport({ ...EMPTY_SUPPORT, ...data.support });
  }, [data]);

  const saveKey = useMutation({
    mutationFn: ({ key, value }: { key: string; value: Record<string, unknown> }) =>
      api(`/api/v1/platform/settings/${key}`, { method: "PUT", json: { value } }),
    onSuccess: async () => {
      setSavedMsg("Сохранено");
      await qc.invalidateQueries({ queryKey: ["platform-settings"] });
      await qc.invalidateQueries({ queryKey: ["oauth-providers"] });
      await qc.invalidateQueries({ queryKey: ["platform-health"] });
      setTimeout(() => setSavedMsg(""), 2000);
    },
  });

  if (isLoading) return <p className="text-sm text-muted">Загрузка…</p>;
  if (error) return <p className="text-sm text-[var(--danger)]">{(error as Error).message}</p>;

  const providers = data?.oauth_providers?.providers ?? {};
  const oauthDirty =
    JSON.stringify(flags) !==
    JSON.stringify({ ...DEFAULT_FLAGS, ...(data?.oauth_login_methods ?? {}) });
  const privacyDirty =
    JSON.stringify(privacy) !==
    JSON.stringify({ ...EMPTY_PRIVACY, ...(data?.privacy_policy ?? {}) });
  const supportDirty =
    JSON.stringify(support) !== JSON.stringify({ ...EMPTY_SUPPORT, ...(data?.support ?? {}) });

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">Настройки</h1>
        <p className="mt-1 text-[13px] text-muted">Входы, поддержка и политика конфиденциальности.</p>
      </div>

      <section className="rounded-[var(--radius)] border border-[var(--border)] bg-white p-4 text-[13px]">
        <h2 className="text-[14px] font-semibold">Роли платформы</h2>
        <ul className="mt-2 space-y-1.5 text-muted">
          <li>
            <span className="font-medium text-foreground">Админ</span> — пользователи (без удаления и
            назначения ролей), проекты, ограничения, модерация, обзор, система
          </li>
          <li>
            <span className="font-medium text-foreground">Суперадмин</span> — всё выше + удаление
            пользователей, роли платформы, эти настройки
          </li>
        </ul>
      </section>

      <section className="rounded-[var(--radius)] border border-[var(--border)] bg-white p-4">
        <h2 className="text-[14px] font-semibold">Способы входа</h2>
        <ul className="mt-3 space-y-2">
          {LABELS.map(({ key, title, hint }) => {
            const meta = key === "email_password" ? null : providers[key];
            const live = key === "email_password" ? flags.email_password : Boolean(meta?.enabled);
            return (
              <li
                key={key}
                className="flex items-center justify-between gap-3 rounded-[10px] border border-[var(--border)] px-3 py-2.5"
              >
                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-2">
                    <p className="text-[14px] font-medium">{title}</p>
                    <span
                      className={cn(
                        "rounded-full px-2 py-0.5 text-[11px] font-semibold",
                        live ? "bg-[#e8f3ec] text-[#2f6b4f]" : "bg-[#f1f3f5] text-[#5a6573]"
                      )}
                    >
                      {live ? "Доступен" : "Скрыт"}
                    </span>
                  </div>
                  <p className="mt-0.5 text-[12px] text-muted">
                    {hint}
                    {meta?.configured === false ? " · нет credentials" : ""}
                    {meta?.policy_blocked ? " · политика РФ" : ""}
                  </p>
                </div>
                <label className="inline-flex shrink-0 cursor-pointer items-center gap-2 text-[13px]">
                  <input
                    type="checkbox"
                    className="size-4 accent-[var(--accent)]"
                    checked={flags[key]}
                    onChange={(e) => setFlags((prev) => ({ ...prev, [key]: e.target.checked }))}
                  />
                  {flags[key] ? "Вкл" : "Выкл"}
                </label>
              </li>
            );
          })}
        </ul>
        <div className="mt-4 flex flex-wrap items-center gap-3">
          <Button
            type="button"
            disabled={saveKey.isPending || !oauthDirty}
            onClick={() => saveKey.mutate({ key: "oauth_login_methods", value: flags })}
          >
            Сохранить входы
          </Button>
        </div>
      </section>

      <section className="rounded-[var(--radius)] border border-[var(--border)] bg-white p-4">
        <h2 className="text-[14px] font-semibold">Поддержка</h2>
        <p className="mt-1 text-[12px] text-muted">Куда писать пользователям по вопросам сервиса.</p>
        <div className="mt-3 grid gap-3 sm:grid-cols-2">
          <label className="block text-[13px]">
            <span className="text-muted">Email</span>
            <Input
              className="mt-1"
              type="email"
              value={support.email}
              onChange={(e) => setSupport((p) => ({ ...p, email: e.target.value }))}
              placeholder="support@taktapp.ru"
            />
          </label>
          <label className="block text-[13px]">
            <span className="text-muted">Telegram</span>
            <Input
              className="mt-1"
              value={support.telegram}
              onChange={(e) => setSupport((p) => ({ ...p, telegram: e.target.value }))}
              placeholder="@takt_support"
            />
          </label>
          <label className="block text-[13px] sm:col-span-2">
            <span className="text-muted">Ссылка на справку / чат</span>
            <Input
              className="mt-1"
              value={support.url}
              onChange={(e) => setSupport((p) => ({ ...p, url: e.target.value }))}
              placeholder="https://…"
            />
          </label>
        </div>
        <div className="mt-4">
          <Button
            type="button"
            disabled={saveKey.isPending || !supportDirty}
            onClick={() => saveKey.mutate({ key: "support", value: support })}
          >
            Сохранить поддержку
          </Button>
        </div>
      </section>

      <section className="rounded-[var(--radius)] border border-[var(--border)] bg-white p-4">
        <h2 className="text-[14px] font-semibold">Политика конфиденциальности</h2>
        <p className="mt-1 text-[12px] text-muted">
          URL публичной страницы и/или текст для ссылки в приложении и на сайте.
        </p>
        <label className="mt-3 block text-[13px]">
          <span className="text-muted">Ссылка</span>
          <Input
            className="mt-1"
            value={privacy.url}
            onChange={(e) => setPrivacy((p) => ({ ...p, url: e.target.value }))}
            placeholder="https://taktapp.ru/privacy"
          />
        </label>
        <label className="mt-3 block text-[13px]">
          <span className="text-muted">Текст (опционально)</span>
          <textarea
            className="mt-1 min-h-[120px] w-full rounded-[var(--radius)] border border-[var(--border)] bg-white px-3 py-2 text-[13px] outline-none focus:border-[var(--accent)]"
            value={privacy.text}
            onChange={(e) => setPrivacy((p) => ({ ...p, text: e.target.value }))}
            placeholder="Краткий текст или примечание для команды"
          />
        </label>
        <div className="mt-4 flex flex-wrap items-center gap-3">
          <Button
            type="button"
            disabled={saveKey.isPending || !privacyDirty}
            onClick={() => saveKey.mutate({ key: "privacy_policy", value: privacy })}
          >
            Сохранить политику
          </Button>
          {savedMsg ? <span className="text-[13px] text-muted">{savedMsg}</span> : null}
          {saveKey.isError ? (
            <span className="text-[13px] text-[var(--danger)]">
              {(saveKey.error as Error).message}
            </span>
          ) : null}
        </div>
      </section>
    </div>
  );
}

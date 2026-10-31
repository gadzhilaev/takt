"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

type MethodFlags = {
  apple: boolean;
  vk: boolean;
  yandex: boolean;
  email_password: boolean;
};

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
  billing_placeholder?: { note?: string };
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

export default function AdminSettingsPage() {
  const qc = useQueryClient();
  const { data, isLoading, error } = useQuery({
    queryKey: ["platform-settings"],
    queryFn: () => api<SettingsResponse>("/api/v1/platform/settings"),
  });
  const [flags, setFlags] = useState<MethodFlags>(DEFAULT_FLAGS);
  const [savedMsg, setSavedMsg] = useState("");

  useEffect(() => {
    if (data?.oauth_login_methods) setFlags({ ...DEFAULT_FLAGS, ...data.oauth_login_methods });
  }, [data?.oauth_login_methods]);

  const save = useMutation({
    mutationFn: (value: MethodFlags) =>
      api("/api/v1/platform/settings/oauth_login_methods", { method: "PUT", json: { value } }),
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
  const dirty =
    JSON.stringify(flags) !==
    JSON.stringify({ ...DEFAULT_FLAGS, ...(data?.oauth_login_methods ?? {}) });

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">Настройки платформы</h1>
        <p className="mt-1 text-[13px] text-muted">
          Управление способами входа для всех пользователей. Credentials в `.env` не удаляются.
        </p>
      </div>

      <section className="rounded-[var(--radius)] border border-[var(--border)] bg-white p-4">
        <h2 className="text-[14px] font-semibold">Способы входа</h2>
        <p className="mt-1 text-[13px] text-muted">
          Выключение скрывает кнопку на сайте и в мобильном приложении.
        </p>
        <ul className="mt-4 space-y-2">
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
                      {live ? "Сейчас доступен" : "Сейчас скрыт"}
                    </span>
                  </div>
                  <p className="mt-0.5 text-[12px] text-muted">
                    {hint}
                    {meta?.configured === false ? " · credentials не заданы" : ""}
                    {meta?.policy_blocked ? " · блокировка политикой РФ" : ""}
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
          <Button type="button" disabled={save.isPending || !dirty} onClick={() => save.mutate(flags)}>
            {save.isPending ? "Сохраняем…" : "Сохранить"}
          </Button>
          {savedMsg ? <span className="text-[13px] text-muted">{savedMsg}</span> : null}
          {dirty && !savedMsg ? (
            <span className="text-[13px] text-muted">Есть несохранённые изменения</span>
          ) : null}
          {save.isError ? (
            <span className="text-[13px] text-[var(--danger)]">{(save.error as Error).message}</span>
          ) : null}
        </div>
        {data?.oauth_providers?.notes?.length ? (
          <ul className="mt-3 list-disc space-y-1 pl-5 text-[12px] text-muted">
            {data.oauth_providers.notes.map((n) => (
              <li key={n}>{n}</li>
            ))}
          </ul>
        ) : null}
      </section>

      <section className="rounded-[var(--radius)] border border-[var(--border)] bg-white p-4">
        <h2 className="text-[14px] font-semibold">Тарифы</h2>
        <p className="mt-2 text-[13px] text-muted">
          {data?.billing_placeholder?.note ?? "Биллинг пока не подключён — заглушка без выдуманных цен."}
        </p>
      </section>
    </div>
  );
}

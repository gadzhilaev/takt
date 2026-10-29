"use client";

import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";

type SettingsResponse = {
  stored: Record<string, unknown>;
  oauth_providers: Record<string, unknown>;
  billing_placeholder?: { note?: string };
};

export default function AdminSettingsPage() {
  const { data, isLoading, error } = useQuery({
    queryKey: ["platform-settings"],
    queryFn: () => api<SettingsResponse>("/api/v1/platform/settings"),
  });

  if (isLoading) return <p className="text-sm text-muted">Загрузка…</p>;
  if (error) return <p className="text-sm text-[var(--danger)]">{(error as Error).message}</p>;

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold tracking-tight">Настройки платформы</h1>
      <section className="rounded-[var(--radius)] border border-[var(--border)] bg-white p-4">
        <h2 className="text-[14px] font-semibold">OAuth-провайдеры</h2>
        <pre className="mt-2 overflow-x-auto text-[12px]">{JSON.stringify(data?.oauth_providers, null, 2)}</pre>
      </section>
      <section className="rounded-[var(--radius)] border border-[var(--border)] bg-white p-4">
        <h2 className="text-[14px] font-semibold">Тарифы</h2>
        <p className="mt-2 text-[13px] text-muted">{data?.billing_placeholder?.note}</p>
      </section>
      <section className="rounded-[var(--radius)] border border-[var(--border)] bg-white p-4">
        <h2 className="text-[14px] font-semibold">Хранимые ключи</h2>
        <pre className="mt-2 overflow-x-auto text-[12px]">{JSON.stringify(data?.stored ?? {}, null, 2)}</pre>
      </section>
    </div>
  );
}

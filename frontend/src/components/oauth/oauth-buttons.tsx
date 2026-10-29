"use client";

import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";

type ProvidersResponse = {
  providers: Record<
    string,
    { id: string; label: string; enabled: boolean; configured: boolean; policy_blocked?: boolean }
  >;
  notes?: string[];
  legal_notice?: string;
};

export function OAuthButtons({ mode = "login" }: { mode?: "login" | "link" }) {
  const [busy, setBusy] = useState<string | null>(null);
  const [err, setErr] = useState("");
  const { data } = useQuery({
    queryKey: ["oauth-providers"],
    queryFn: () => api<ProvidersResponse>("/api/v1/auth/oauth/providers"),
  });

  const providers = data?.providers ?? {};
  const enabled = Object.values(providers).filter((p) => p.enabled);

  async function start(provider: string) {
    setErr("");
    setBusy(provider);
    try {
      const res = await api<{ authorize_url: string }>(
        `/api/v1/auth/oauth/${provider}/start?client=web${mode === "link" ? "&link=true" : ""}`
      );
      window.location.href = res.authorize_url;
    } catch (e) {
      setErr(e instanceof Error ? e.message : "Не удалось начать вход");
      setBusy(null);
    }
  }

  if (!enabled.length) {
    return (
      <p className="text-[12px] leading-snug text-muted">
        Вход через Apple / VK ID / Яндекс ID будет доступен после настройки провайдеров на сервере.
        {data?.notes?.[0] ? ` ${data.notes[0]}` : ""}
      </p>
    );
  }

  return (
    <div className="space-y-2">
      <div className="relative my-4 text-center text-[12px] text-muted">
        <span className="bg-[var(--surface)] relative z-[1] px-2">или</span>
        <span className="absolute left-0 right-0 top-1/2 h-px bg-[var(--border)]" aria-hidden />
      </div>
      {enabled.map((p) => (
        <Button
          key={p.id}
          type="button"
          variant="secondary"
          className="w-full justify-center"
          disabled={busy !== null}
          onClick={() => start(p.id)}
        >
          {busy === p.id ? "Перенаправление…" : `Продолжить с ${p.label}`}
        </Button>
      ))}
      {err && (
        <p className="rounded-[var(--radius)] bg-[var(--danger-soft)] px-3 py-2 text-sm text-[var(--danger)]" role="alert">
          {err}
        </p>
      )}
      {data?.legal_notice && <p className="text-[11px] leading-snug text-muted">{data.legal_notice}</p>}
    </div>
  );
}

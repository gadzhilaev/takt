"use client";

import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";

type ProvidersResponse = {
  email_password?: boolean;
  providers: Record<
    string,
    { id: string; label: string; enabled: boolean; configured: boolean; policy_blocked?: boolean }
  >;
  notes?: string[];
  legal_notice?: string;
};

export function useOAuthProviders() {
  return useQuery({
    queryKey: ["oauth-providers"],
    queryFn: () => api<ProvidersResponse>("/api/v1/auth/oauth/providers"),
  });
}

const PROVIDER_ICONS: Record<string, { src: string; alt: string }> = {
  vk: { src: "/brand/oauth-vk.svg", alt: "VK" },
  yandex: { src: "/brand/oauth-yandex.svg", alt: "Яндекс" },
};

/** Web: только VK / Яндекс. Apple — только в мобильном приложении. */
const WEB_PROVIDERS = new Set(["vk", "yandex"]);

export function OAuthButtons({
  mode = "login",
  next,
}: {
  mode?: "login" | "register" | "link";
  /** Preserve invite / deep link through OAuth redirect (e.g. /invite/{token}). */
  next?: string | null;
}) {
  const [busy, setBusy] = useState<string | null>(null);
  const [err, setErr] = useState("");
  const { data } = useOAuthProviders();

  const providers = data?.providers ?? {};
  const enabled = Object.values(providers).filter((p) => p.enabled && WEB_PROVIDERS.has(p.id));
  const actionLabel = "Продолжить с";

  async function start(provider: string) {
    setErr("");
    setBusy(provider);
    try {
      const qs = new URLSearchParams({ client: "web" });
      if (mode === "link") qs.set("link", "true");
      if (next && next.startsWith("/") && !next.startsWith("//")) {
        qs.set("next", next);
      }
      const res = await api<{ authorize_url: string }>(
        `/api/v1/auth/oauth/${provider}/start?${qs.toString()}`
      );
      window.location.href = res.authorize_url;
    } catch (e) {
      setErr(e instanceof Error ? e.message : "");
      setBusy(null);
    }
  }

  if (!enabled.length) {
    return (
      <p className="mt-4 text-[12px] leading-snug text-muted">
        Вход через VK ID / Яндекс ID будет доступен после настройки провайдеров на сервере.
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
      {enabled.map((p) => {
        const icon = PROVIDER_ICONS[p.id];
        return (
          <Button
            key={p.id}
            type="button"
            variant="secondary"
            className="w-full justify-center gap-2.5 rounded-full"
            disabled={busy !== null}
            onClick={() => start(p.id)}
          >
            {icon ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={`${icon.src}?v=2`}
                alt=""
                width={22}
                height={22}
                className="size-[22px] shrink-0 rounded-[7px] object-contain"
              />
            ) : null}
            <span>{busy === p.id ? "Перенаправление…" : `${actionLabel} ${p.label}`}</span>
          </Button>
        );
      })}
      {err && (
        <p className="rounded-[var(--radius)] bg-[var(--danger-soft)] px-3 py-2 text-sm text-[var(--danger)]" role="alert">
          {err}
        </p>
      )}
      {data?.legal_notice && <p className="text-[11px] leading-snug text-muted">{data.legal_notice}</p>}
    </div>
  );
}

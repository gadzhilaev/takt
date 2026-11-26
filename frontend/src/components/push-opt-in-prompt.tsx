"use client";

import { useEffect, useState } from "react";
import { AppIcon } from "@/components/ui/app-icon";
import { Button } from "@/components/ui/button";
import { api } from "@/lib/api";
import { enableWebPush } from "@/lib/web-push";

const NEVER_KEY = "takt_push_prompt_never_v2";

export function PushOptInPrompt() {
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    let active = true;
    const timer = window.setTimeout(() => {
      void (async () => {
        if (
          !("Notification" in window) ||
          !("serviceWorker" in navigator) ||
          !("PushManager" in window) ||
          localStorage.getItem(NEVER_KEY) === "1"
        ) {
          return;
        }
        try {
          const [vapid, state] = await Promise.all([
            api<{ public_key: string | null; configured: boolean }>(
              "/api/v1/notifications/push/vapid-public-key"
            ),
            api<{ subscribed: boolean }>("/api/v1/notifications/push/status"),
          ]);
          if (active && vapid.configured && vapid.public_key && !state.subscribed) {
            if (Notification.permission === "denied") {
              setError(
                "Уведомления заблокированы браузером. Разрешите их в настройках сайта, затем обновите страницу."
              );
            }
            setOpen(true);
          }
        } catch {
          // A transient auth/network error should not show a misleading prompt.
        }
      })();
    }, 700);

    return () => {
      active = false;
      window.clearTimeout(timer);
    };
  }, []);

  async function allow() {
    if (Notification.permission === "denied") {
      setError(
        "Уведомления заблокированы браузером. Разрешите их в настройках сайта и обновите страницу."
      );
      return;
    }
    setBusy(true);
    setError("");
    try {
      const result = await enableWebPush();
      if (!result.ok) {
        setError(result.message);
        return;
      }
      localStorage.setItem(NEVER_KEY, "1");
      setOpen(false);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Не удалось включить уведомления");
    } finally {
      setBusy(false);
    }
  }

  function later() {
    localStorage.setItem(NEVER_KEY, "1");
    setOpen(false);
  }

  if (!open) return null;

  return (
    <div className="fixed bottom-4 right-4 z-[80] w-[calc(100%-2rem)] max-w-[360px]" role="dialog" aria-label="Браузерные уведомления">
      <section className="rounded-[var(--radius-lg)] border border-hairline bg-[var(--surface)] p-4 shadow-[0_12px_40px_rgba(0,0,0,0.18)]">
        <div className="flex items-start gap-3">
          <span className="flex size-10 shrink-0 items-center justify-center rounded-[12px] bg-[var(--accent-soft)] text-[var(--accent)]">
            <AppIcon name="notifications" size={22} />
          </span>
          <div className="min-w-0 flex-1">
            <h2 className="text-sm font-semibold tracking-tight">Включить уведомления?</h2>
            <p className="mt-1 text-xs leading-relaxed text-muted">
              Сообщим о новых задачах, комментариях и изменениях в проектах.
            </p>
          </div>
          <button type="button" className="-mr-1 -mt-1 rounded p-1 text-muted hover:text-foreground" aria-label="Не сейчас" onClick={later}>
            <AppIcon name="close" size={16} />
          </button>
        </div>
        {error ? <p role="alert" className="mt-3 text-xs leading-relaxed text-[var(--danger)]">{error}</p> : null}
        <div className="mt-3 flex justify-end gap-2">
          <Button type="button" size="sm" variant="ghost" onClick={later} disabled={busy}>Не сейчас</Button>
          <Button type="button" size="sm" onClick={() => void allow()} disabled={busy}>
            {busy ? "Подключаем…" : "Включить"}
          </Button>
        </div>
      </section>
    </div>
  );
}

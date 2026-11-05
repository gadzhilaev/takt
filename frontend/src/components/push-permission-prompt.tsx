"use client";

import { AppIcon } from "@/components/ui/app-icon";
import { Button } from "@/components/ui/button";
import { setPushPromptNever, shouldShowPushPrompt } from "@/lib/push-prompt";
import { enableWebPush } from "@/lib/web-push";
import { useEffect, useState } from "react";

export function PushPermissionPrompt() {
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const t = window.setTimeout(() => {
      if (shouldShowPushPrompt()) setOpen(true);
    }, 600);
    return () => window.clearTimeout(t);
  }, []);

  async function onAllow() {
    setBusy(true);
    try {
      await enableWebPush();
    } catch {
      /* ignore — in-app feed still works */
    } finally {
      setPushPromptNever();
      setOpen(false);
    }
  }

  function onNotNow() {
    // Don't ask on every visit — can enable later in profile.
    setPushPromptNever();
    setOpen(false);
  }

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[80] flex items-center justify-center p-4" role="dialog" aria-modal="true">
      <button
        type="button"
        className="absolute inset-0 bg-black/30"
        aria-label="Закрыть"
        onClick={onNotNow}
      />
      <div className="relative z-10 w-full max-w-[380px] rounded-[var(--radius-lg)] border border-hairline bg-[var(--surface)] p-5 shadow-sm">
        <div className="mx-auto flex h-11 w-11 items-center justify-center rounded-[12px] bg-[var(--accent-soft)] text-[var(--accent)]">
          <AppIcon name="notifications" size={22} />
        </div>
        <h2 className="mt-3 text-center text-[17px] font-semibold tracking-tight">
          Будьте в курсе важных событий
        </h2>
        <p className="mt-2 text-center text-sm leading-relaxed text-muted">
          Узнавайте о новых задачах, комментариях и изменениях в проектах.
        </p>
        <ul className="mt-4 space-y-2.5 text-sm text-foreground">
          <li className="flex gap-2.5">
            <AppIcon name="assignment" size={18} className="mt-0.5 shrink-0 text-[var(--accent)]" />
            Назначения и новые задачи
          </li>
          <li className="flex gap-2.5">
            <AppIcon name="forum" size={18} className="mt-0.5 shrink-0 text-[var(--accent)]" />
            Упоминания и комментарии
          </li>
          <li className="flex gap-2.5">
            <AppIcon name="status" size={18} className="mt-0.5 shrink-0 text-[var(--accent)]" />
            Важные изменения задач
          </li>
        </ul>
        <div className="mt-5 flex flex-col gap-1.5">
          <Button type="button" disabled={busy} onClick={() => void onAllow()}>
            {busy ? "Подключаем…" : "Разрешить уведомления"}
          </Button>
          <Button type="button" variant="ghost" disabled={busy} onClick={onNotNow}>
            Не сейчас
          </Button>
        </div>
      </div>
    </div>
  );
}

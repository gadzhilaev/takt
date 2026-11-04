"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { BrandLogo } from "@/components/brand-mark";
import { Button } from "@/components/ui/button";
import { api, messageFromApiError } from "@/lib/api";
import type { User } from "@/lib/types";

/**
 * Public account-deletion page required by Google Play / store policies.
 * Logged-in users can delete in-app; guests get login + support instructions.
 */
export default function AccountDeletePage() {
  const [user, setUser] = useState<User | null | undefined>(undefined);
  const [busy, setBusy] = useState(false);
  const [confirm, setConfirm] = useState("");
  const [msg, setMsg] = useState("");
  const [err, setErr] = useState("");

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        // Raw fetch: api() redirects guests to /login on 401.
        const res = await fetch("/api/v1/auth/me", { credentials: "include" });
        if (!res.ok) {
          if (!cancelled) setUser(null);
          return;
        }
        const data = (await res.json()) as { user: User };
        if (!cancelled) setUser(data.user);
      } catch {
        if (!cancelled) setUser(null);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  async function deleteAccount() {
    setErr("");
    setMsg("");
    if (confirm.trim().toUpperCase() !== "УДАЛИТЬ") {
      setErr('Введите слово УДАЛИТЬ заглавными буквами для подтверждения');
      return;
    }
    setBusy(true);
    try {
      await api("/api/v1/users/me", { method: "DELETE" });
      setMsg("Аккаунт удалён. Сессия завершена.");
      setUser(null);
      setConfirm("");
    } catch (e) {
      setErr(messageFromApiError(e) || (e as Error).message || "Не удалось удалить аккаунт");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="min-h-screen bg-[var(--bg)] text-foreground">
      <header className="border-b border-hairline">
        <div className="mx-auto flex max-w-3xl items-center justify-between px-4 py-4 sm:px-6">
          <Link href="/" className="inline-flex items-center gap-2" aria-label="Takt">
            <BrandLogo className="h-7 w-auto" />
          </Link>
          <Link href="/login" className="text-[13px] text-muted hover:text-foreground">
            Вход
          </Link>
        </div>
      </header>

      <main className="mx-auto max-w-3xl px-4 py-10 sm:px-6 sm:py-14">
        <h1 className="text-[28px] font-semibold tracking-tight sm:text-[32px]">
          Удаление аккаунта
        </h1>
        <p className="mt-2 text-[14px] text-muted">
          Удаление необратимо: профиль обезличивается, сессии и push-токены отзываются.
          Проекты, где вы единственный участник, удаляются. Общие проекты команды сохраняются —
          если вы единственный администратор с другими участниками, сначала назначьте другого
          администратора.
        </p>

        {user === undefined && (
          <p className="mt-8 text-[14px] text-muted">Проверяем сессию…</p>
        )}

        {user === null && (
          <div className="mt-8 space-y-4 rounded-lg border border-hairline p-5">
            <p className="text-[15px] leading-relaxed">
              Войдите в Takt, чтобы удалить аккаунт самостоятельно, либо напишите на{" "}
              <a
                className="text-[var(--accent)] underline-offset-2 hover:underline"
                href="mailto:support@taktapp.ru?subject=Удаление%20аккаунта%20Takt"
              >
                support@taktapp.ru
              </a>{" "}
              с адреса, привязанного к аккаунту.
            </p>
            <Button asChild>
              <Link href="/login?next=/account-delete">Войти и удалить</Link>
            </Button>
          </div>
        )}

        {user && (
          <div className="mt-8 space-y-4 rounded-lg border border-hairline p-5">
            <p className="text-[14px] text-muted">
              Вы вошли как <span className="text-foreground">{user.email}</span> ({user.name}).
            </p>
            <label className="block text-[13px] text-muted">
              Для подтверждения введите <span className="text-foreground">УДАЛИТЬ</span>
              <input
                className="mt-1.5 w-full rounded-md border border-hairline bg-transparent px-3 py-2 text-[15px]"
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
                autoComplete="off"
                disabled={busy}
              />
            </label>
            <Button
              variant="destructive"
              disabled={busy}
              onClick={deleteAccount}
            >
              {busy ? "Удаляем…" : "Удалить аккаунт навсегда"}
            </Button>
          </div>
        )}

        {msg && <p className="mt-4 text-sm text-[var(--success)]">{msg}</p>}
        {err && <p className="mt-4 text-sm text-[var(--danger)]">{err}</p>}

        <p className="mt-10 text-[13px] text-muted">
          Политика:{" "}
          <Link href="/privacy" className="text-[var(--accent)] underline-offset-2 hover:underline">
            /privacy
          </Link>
          . В приложении удаление доступно в профиле.
        </p>
      </main>
    </div>
  );
}

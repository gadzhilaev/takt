"use client";

import { AppIcon } from "@/components/ui/app-icon";
import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import Link from "next/link";
import { BrandLogo } from "@/components/brand-mark";
import { OAuthButtons, useOAuthProviders } from "@/components/oauth/oauth-buttons";
import { paths } from "@/lib/paths";

// Клиентская валидация без текстов — сообщения ошибок только с API.
const schema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

function safeNext(raw: string | null): string {
  if (!raw || !raw.startsWith("/") || raw.startsWith("//")) return paths.projects;
  if (raw.startsWith("/login") || raw.startsWith("/register")) return paths.projects;
  return raw;
}

function serverFacingText(raw: string | null): string {
  const msg = (raw || "").trim();
  if (!msg) return "";
  // Код ошибки без текста — не показываем сырой snake_case.
  if (/^[a-z][a-z0-9_]+$/i.test(msg)) return "";
  return msg;
}

function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [show, setShow] = useState(false);
  const rawMessage = searchParams.get("message");
  const hasOauthError = Boolean(searchParams.get("oauth_error"));
  const fromServer = serverFacingText(rawMessage);
  const [error, setError] = useState(hasOauthError ? fromServer : "");
  const [info, setInfo] = useState(!hasOauthError ? fromServer : "");
  const form = useForm({ resolver: zodResolver(schema), defaultValues: { email: "", password: "" } });
  const { data: oauthMeta } = useOAuthProviders();
  const emailPassword = oauthMeta?.email_password !== false;

  // Refresh-only cookie: silently renew and enter the app (middleware no longer bounces on refresh alone).
  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL ?? ""}/api/v1/auth/refresh`, {
          method: "POST",
          credentials: "include",
          headers: { "Content-Type": "application/json" },
          body: "{}",
        });
        if (!cancelled && res.ok) {
          router.replace(safeNext(searchParams.get("next")));
        }
      } catch {
        /* stay on login */
      }
    })();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- once on mount
  }, []);

  // Показать сообщение один раз, затем убрать его из URL — иначе refresh снова поднимает алерт.
  useEffect(() => {
    if (!searchParams.get("message") && !searchParams.get("oauth_error")) return;
    const next = searchParams.get("next");
    const qs = next ? `?next=${encodeURIComponent(next)}` : "";
    router.replace(`${paths.login}${qs}`);
  }, [router, searchParams]);

  useEffect(() => {
    if (!hasOauthError && fromServer) setInfo(fromServer);
    if (hasOauthError && fromServer) setError(fromServer);
  }, [fromServer, hasOauthError]);

  async function onSubmit(values: z.infer<typeof schema>) {
    setError("");
    setInfo("");
    try {
      const res = await api<{ user: { must_change_password: boolean } }>("/api/v1/auth/login", {
        method: "POST",
        json: values,
      });
      if (res.user.must_change_password) router.push(paths.changePassword);
      else router.push(safeNext(searchParams.get("next")));
    } catch (e) {
      setError(e instanceof Error ? e.message : "");
    }
  }

  return (
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden bg-background p-4">
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_top,_rgba(49,95,114,0.12),_transparent_55%),linear-gradient(180deg,var(--background),color-mix(in_srgb,var(--accent)_6%,var(--background)))]"
      />
      <div className="relative w-full max-w-sm">
        <div className="mb-7 px-1">
          <Link href={paths.home} className="inline-flex" aria-label="Takt на главную">
            <BrandLogo className="h-9 w-auto max-w-[11.5rem]" title="Takt" />
          </Link>
        </div>
        <div className="surface-panel p-6 sm:p-7">
          <div className="mb-6">
            <h1 className="text-xl font-semibold tracking-tight">Вход</h1>
            <p className="mt-1.5 text-[13px] leading-snug text-muted">
              Войдите, чтобы открыть доску команды
            </p>
          </div>
          {emailPassword ? (
            <form className="space-y-3.5" method="post" action="#" onSubmit={form.handleSubmit(onSubmit)}>
              <div>
                <label className="label-text" htmlFor="login-email">
                  Email
                </label>
                <Input id="login-email" type="email" autoComplete="email" {...form.register("email")} />
              </div>
              <div>
                <div className="mb-1.5 flex items-center justify-between gap-2">
                  <label className="label-text mb-0" htmlFor="login-password">
                    Пароль
                  </label>
                  <Link
                    href={paths.forgotPassword}
                    className="text-[12px] font-medium text-[var(--accent)] hover:underline"
                  >
                    Забыли пароль?
                  </Link>
                </div>
                <div className="relative">
                  <Input
                    id="login-password"
                    type={show ? "text" : "password"}
                    autoComplete="current-password"
                    {...form.register("password")}
                  />
                  <button
                    type="button"
                    className="absolute right-1.5 top-1/2 -translate-y-1/2 rounded-[var(--radius-sm)] p-1.5 text-muted hover:bg-[var(--surface-2)]"
                    onClick={() => setShow((s) => !s)}
                    aria-label={show ? "Скрыть пароль" : "Показать пароль"}
                  >
                    {show ? <AppIcon name="eye-off" size={16} /> : <AppIcon name="eye" size={16} />}
                  </button>
                </div>
              </div>
              {info && !error && (
                <p className="rounded-[var(--radius)] bg-[color-mix(in_srgb,var(--accent)_12%,transparent)] px-3 py-2 text-sm text-[var(--accent)]">
                  {info}
                </p>
              )}
              {error && (
                <p className="rounded-[var(--radius)] bg-[var(--danger-soft)] px-3 py-2 text-sm text-[var(--danger)]" role="alert">
                  {error}
                </p>
              )}
              <Button type="submit" className="w-full" size="lg" disabled={form.formState.isSubmitting}>
                {form.formState.isSubmitting ? "Входим…" : "Войти"}
              </Button>
            </form>
          ) : error ? (
            <p className="rounded-[var(--radius)] bg-[var(--danger-soft)] px-3 py-2 text-sm text-[var(--danger)]" role="alert">
              {error}
            </p>
          ) : null}
          <OAuthButtons mode="login" next={searchParams.get("next")} />
          <p className="mt-5 text-center text-sm text-muted">
            Нет аккаунта?{" "}
            <Link
              href={
                searchParams.get("next")
                  ? `${paths.register}?next=${encodeURIComponent(searchParams.get("next")!)}`
                  : paths.register
              }
              className="font-medium text-[var(--accent)]"
            >
              Регистрация
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}

export default function LoginPage() {
  return (
    <Suspense fallback={<div className="min-h-screen bg-background" />}>
      <LoginForm />
    </Suspense>
  );
}

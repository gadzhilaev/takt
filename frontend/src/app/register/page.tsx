"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { BrandLogo } from "@/components/brand-mark";
import { OAuthButtons, useOAuthProviders } from "@/components/oauth/oauth-buttons";
import { paths } from "@/lib/paths";
import { setLastProjectId } from "@/lib/last-project";

function safeNext(raw: string | null): string {
  if (!raw || !raw.startsWith("/") || raw.startsWith("//")) return paths.projects;
  if (raw.startsWith("/login") || raw.startsWith("/register")) return paths.projects;
  return raw;
}

function inviteTokenFromNext(raw: string | null): string | undefined {
  if (!raw) return undefined;
  const m = raw.match(/^\/invite\/([^/?#]+)/);
  return m?.[1];
}

// Без клиентских текстов ошибок — тексты приходят с API (validation + auth).
const schema = z
  .object({
    name: z.string().min(1),
    email: z.string().email(),
    password: z.string().min(8),
    password_confirm: z.string().min(8),
  })
  .refine((v) => v.password === v.password_confirm, {
    message: " ",
    path: ["password_confirm"],
  });

type FormValues = z.infer<typeof schema>;

function RegisterForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [error, setError] = useState("");
  const [step, setStep] = useState<"form" | "code">("form");
  const [pending, setPending] = useState<FormValues | null>(null);
  const [code, setCode] = useState("");
  const [sending, setSending] = useState(false);
  const form = useForm({
    resolver: zodResolver(schema),
    defaultValues: { name: "", email: "", password: "", password_confirm: "" },
  });
  const { data: oauthMeta } = useOAuthProviders();
  const emailPassword = oauthMeta?.email_password !== false;

  async function onSubmit(values: FormValues) {
    setError("");
    setSending(true);
    try {
      await api("/api/v1/auth/register/send-code", { method: "POST", json: values });
      setPending(values);
      setStep("code");
    } catch (e) {
      setError(e instanceof Error ? e.message : "");
    } finally {
      setSending(false);
    }
  }

  async function onConfirm(e: React.FormEvent) {
    e.preventDefault();
    if (!pending) return;
    setError("");
    setSending(true);
    try {
      const next = searchParams.get("next");
      const inviteToken = inviteTokenFromNext(next);
      const res = await api<{ joined_project_id?: string | null }>("/api/v1/auth/register/confirm", {
        method: "POST",
        json: {
          email: pending.email,
          code: code.trim(),
          ...(inviteToken ? { invite_token: inviteToken } : {}),
        },
      });
      if (res.joined_project_id) {
        setLastProjectId(res.joined_project_id);
        router.push(paths.project(res.joined_project_id));
        return;
      }
      router.push(safeNext(next));
    } catch (err) {
      setError(err instanceof Error ? err.message : "");
    } finally {
      setSending(false);
    }
  }

  async function resend() {
    if (!pending) return;
    setError("");
    setSending(true);
    try {
      await api("/api/v1/auth/register/send-code", { method: "POST", json: pending });
    } catch (e) {
      setError(e instanceof Error ? e.message : "");
    } finally {
      setSending(false);
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
          <Link href="/" className="inline-flex" aria-label="Takt на главную">
            <BrandLogo className="h-9 w-auto max-w-[11.5rem]" title="Takt" />
          </Link>
        </div>
        <div className="surface-panel p-6 sm:p-7">
          <div className="mb-6">
            <h1 className="text-xl font-semibold tracking-tight">
              {step === "form" ? "Регистрация" : "Код из письма"}
            </h1>
            <p className="mt-1.5 text-[13px] leading-snug text-muted">
              {step === "form"
                ? "Создайте аккаунт — пришлём код подтверждения на email"
                : `Введите код, отправленный на ${pending?.email}`}
            </p>
          </div>

          {step === "form" ? (
            <>
              {emailPassword ? (
                <form className="space-y-3" onSubmit={form.handleSubmit(onSubmit)}>
                  <div>
                    <label className="label-text" htmlFor="reg-name">
                      Имя
                    </label>
                    <Input id="reg-name" autoComplete="name" {...form.register("name")} />
                    {form.formState.errors.name && (
                      <p className="mt-1 text-xs text-[var(--danger)]">{form.formState.errors.name.message}</p>
                    )}
                  </div>
                  <div>
                    <label className="label-text" htmlFor="reg-email">
                      Email
                    </label>
                    <Input id="reg-email" type="email" autoComplete="email" {...form.register("email")} />
                    {form.formState.errors.email && (
                      <p className="mt-1 text-xs text-[var(--danger)]">{form.formState.errors.email.message}</p>
                    )}
                  </div>
                  <div>
                    <label className="label-text" htmlFor="reg-pass">
                      Пароль
                    </label>
                    <Input id="reg-pass" type="password" autoComplete="new-password" {...form.register("password")} />
                    {form.formState.errors.password && (
                      <p className="mt-1 text-xs text-[var(--danger)]">{form.formState.errors.password.message}</p>
                    )}
                  </div>
                  <div>
                    <label className="label-text" htmlFor="reg-pass2">
                      Подтверждение пароля
                    </label>
                    <Input
                      id="reg-pass2"
                      type="password"
                      autoComplete="new-password"
                      {...form.register("password_confirm")}
                    />
                    {form.formState.errors.password_confirm && (
                      <p className="mt-1 text-xs text-[var(--danger)]">
                        {form.formState.errors.password_confirm.message}
                      </p>
                    )}
                  </div>
                  {error && (
                    <p className="rounded-[var(--radius)] bg-[var(--danger-soft)] px-3 py-2 text-sm text-[var(--danger)]">
                      {error}
                    </p>
                  )}
                  <Button type="submit" className="w-full" size="lg" disabled={sending || form.formState.isSubmitting}>
                    Продолжить
                  </Button>
                </form>
              ) : error ? (
                <p className="rounded-[var(--radius)] bg-[var(--danger-soft)] px-3 py-2 text-sm text-[var(--danger)]">
                  {error}
                </p>
              ) : null}
              <OAuthButtons mode="register" />
            </>
          ) : (
            <form className="space-y-3" onSubmit={onConfirm}>
              <div>
                <label className="label-text" htmlFor="reg-code">
                  Код из письма
                </label>
                <Input
                  id="reg-code"
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  value={code}
                  onChange={(e) => setCode(e.target.value)}
                  placeholder="6 цифр"
                />
              </div>
              {error && (
                <p className="rounded-[var(--radius)] bg-[var(--danger-soft)] px-3 py-2 text-sm text-[var(--danger)]">
                  {error}
                </p>
              )}
              <Button type="submit" className="w-full" size="lg" disabled={sending || code.trim().length < 4}>
                Подтвердить
              </Button>
              <Button type="button" variant="ghost" className="w-full" disabled={sending} onClick={resend}>
                Отправить код ещё раз
              </Button>
              <Button
                type="button"
                variant="ghost"
                className="w-full"
                disabled={sending}
                onClick={() => {
                  setStep("form");
                  setCode("");
                  setError("");
                }}
              >
                Изменить данные
              </Button>
            </form>
          )}

          <p className="mt-5 text-center text-sm text-muted">
            Уже есть аккаунт?{" "}
            <Link
              href={
                searchParams.get("next")
                  ? `${paths.login}?next=${encodeURIComponent(searchParams.get("next")!)}`
                  : paths.login
              }
              className="font-medium text-[var(--accent)]"
            >
              Войти
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}

export default function RegisterPage() {
  return (
    <Suspense fallback={null}>
      <RegisterForm />
    </Suspense>
  );
}

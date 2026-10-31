"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { PasswordInput } from "@/components/ui/password-input";
import { BrandLogo } from "@/components/brand-mark";
import { paths } from "@/lib/paths";

type SendCodeResponse = { ok?: boolean; message?: string; email?: string };

export default function ForgotPasswordPage() {
  const router = useRouter();
  const [error, setError] = useState("");
  const [info, setInfo] = useState("");
  const [step, setStep] = useState<"email" | "reset">("email");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [password, setPassword] = useState("");
  const [passwordConfirm, setPasswordConfirm] = useState("");
  const [sending, setSending] = useState(false);

  async function onSend(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setInfo("");
    setSending(true);
    try {
      const res = await api<SendCodeResponse>("/api/v1/auth/forgot-password/send-code", {
        method: "POST",
        json: { email: email.trim() },
      });
      setEmail((res.email || email).trim());
      setInfo(res.message || "");
      setStep("reset");
    } catch (err) {
      setError(err instanceof Error ? err.message : "");
    } finally {
      setSending(false);
    }
  }

  async function onConfirm(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setInfo("");
    setSending(true);
    try {
      const res = await api<{ ok?: boolean; message?: string }>("/api/v1/auth/forgot-password/confirm", {
        method: "POST",
        json: {
          email,
          code: code.trim(),
          new_password: password,
          new_password_confirm: passwordConfirm,
        },
      });
      const msg = res.message || "";
      router.push(msg ? `${paths.login}?message=${encodeURIComponent(msg)}` : paths.login);
    } catch (err) {
      setError(err instanceof Error ? err.message : "");
    } finally {
      setSending(false);
    }
  }

  async function resend() {
    if (!email) return;
    setError("");
    setInfo("");
    setSending(true);
    try {
      const res = await api<SendCodeResponse>("/api/v1/auth/forgot-password/send-code", {
        method: "POST",
        json: { email },
      });
      setInfo(res.message || "");
    } catch (err) {
      setError(err instanceof Error ? err.message : "");
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
          <Link href={paths.home} className="inline-flex" aria-label="Takt на главную">
            <BrandLogo className="h-9 w-auto max-w-[11.5rem]" title="Takt" />
          </Link>
        </div>
        <div className="surface-panel p-6 sm:p-7">
          <div className="mb-6">
            <h1 className="text-xl font-semibold tracking-tight">
              {step === "email" ? "Сброс пароля" : "Новый пароль"}
            </h1>
            <p className="mt-1.5 text-[13px] leading-snug text-muted">
              {step === "email"
                ? "Укажите email — пришлём код для сброса пароля"
                : `Введите код из письма на ${email} и задайте новый пароль`}
            </p>
          </div>

          {step === "email" ? (
            <form className="space-y-3.5" noValidate onSubmit={onSend}>
              <div>
                <label className="label-text" htmlFor="forgot-email">
                  Email
                </label>
                <Input
                  id="forgot-email"
                  type="email"
                  autoComplete="email"
                  value={email}
                  onChange={(ev) => setEmail(ev.target.value)}
                  required
                />
              </div>
              {error ? (
                <p className="rounded-[var(--radius)] bg-[var(--danger-soft)] px-3 py-2 text-sm text-[var(--danger)]">
                  {error}
                </p>
              ) : null}
              <Button type="submit" className="w-full" size="lg" disabled={sending}>
                {sending ? "…" : "Отправить код"}
              </Button>
            </form>
          ) : (
            <form className="space-y-3.5" onSubmit={onConfirm}>
              {info ? (
                <p className="rounded-[var(--radius)] bg-[color-mix(in_srgb,var(--accent)_12%,transparent)] px-3 py-2 text-sm text-[var(--accent)]">
                  {info}
                </p>
              ) : null}
              <div>
                <label className="label-text" htmlFor="forgot-code">
                  Код из письма
                </label>
                <Input
                  id="forgot-code"
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  value={code}
                  onChange={(ev) => setCode(ev.target.value)}
                  required
                />
              </div>
              <div>
                <label className="label-text" htmlFor="forgot-pass">
                  Новый пароль
                </label>
                <PasswordInput
                  id="forgot-pass"
                  autoComplete="new-password"
                  value={password}
                  onChange={(ev) => setPassword(ev.target.value)}
                  minLength={8}
                  required
                />
              </div>
              <div>
                <label className="label-text" htmlFor="forgot-pass2">
                  Подтверждение пароля
                </label>
                <PasswordInput
                  id="forgot-pass2"
                  autoComplete="new-password"
                  value={passwordConfirm}
                  onChange={(ev) => setPasswordConfirm(ev.target.value)}
                  minLength={8}
                  required
                />
              </div>
              {error ? (
                <p className="rounded-[var(--radius)] bg-[var(--danger-soft)] px-3 py-2 text-sm text-[var(--danger)]">
                  {error}
                </p>
              ) : null}
              <Button type="submit" className="w-full" size="lg" disabled={sending}>
                {sending ? "…" : "Сбросить пароль"}
              </Button>
              <button
                type="button"
                className="w-full text-center text-sm text-[var(--accent)]"
                onClick={resend}
                disabled={sending}
              >
                Отправить код ещё раз
              </button>
            </form>
          )}

          <p className="mt-5 text-center text-sm text-muted">
            Вспомнили пароль?{" "}
            <Link href={paths.login} className="font-medium text-[var(--accent)]">
              Войти
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}

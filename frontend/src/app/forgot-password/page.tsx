"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { BrandLogo } from "@/components/brand-mark";
import { paths } from "@/lib/paths";

const emailSchema = z.object({
  email: z.string().email("Введите корректный email"),
});

const resetSchema = z
  .object({
    code: z.string().min(4, "Введите код из письма"),
    new_password: z.string().min(8, "Минимум 8 символов"),
    new_password_confirm: z.string().min(8, "Минимум 8 символов"),
  })
  .refine((v) => v.new_password === v.new_password_confirm, {
    message: "Пароли не совпадают",
    path: ["new_password_confirm"],
  });

type EmailValues = z.infer<typeof emailSchema>;
type ResetValues = z.infer<typeof resetSchema>;

export default function ForgotPasswordPage() {
  const router = useRouter();
  const [error, setError] = useState("");
  const [step, setStep] = useState<"email" | "reset">("email");
  const [email, setEmail] = useState("");
  const [sending, setSending] = useState(false);

  const emailForm = useForm({
    resolver: zodResolver(emailSchema),
    defaultValues: { email: "" },
  });
  const resetForm = useForm({
    resolver: zodResolver(resetSchema),
    defaultValues: { code: "", new_password: "", new_password_confirm: "" },
  });

  async function onSend(values: EmailValues) {
    setError("");
    setSending(true);
    try {
      await api("/api/v1/auth/forgot-password/send-code", {
        method: "POST",
        json: { email: values.email.trim() },
      });
      setEmail(values.email.trim());
      setStep("reset");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Не удалось отправить код");
    } finally {
      setSending(false);
    }
  }

  async function onConfirm(values: ResetValues) {
    setError("");
    setSending(true);
    try {
      await api("/api/v1/auth/forgot-password/confirm", {
        method: "POST",
        json: {
          email,
          code: values.code.trim(),
          new_password: values.new_password,
          new_password_confirm: values.new_password_confirm,
        },
      });
      router.push(`${paths.login}?message=${encodeURIComponent("Пароль обновлён. Войдите с новым паролем.")}`);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Не удалось сбросить пароль");
    } finally {
      setSending(false);
    }
  }

  async function resend() {
    if (!email) return;
    setError("");
    setSending(true);
    try {
      await api("/api/v1/auth/forgot-password/send-code", {
        method: "POST",
        json: { email },
      });
    } catch (e) {
      setError(e instanceof Error ? e.message : "Не удалось отправить код");
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
            <form className="space-y-3.5" onSubmit={emailForm.handleSubmit(onSend)}>
              <div>
                <label className="label-text" htmlFor="forgot-email">
                  Email
                </label>
                <Input id="forgot-email" type="email" autoComplete="email" {...emailForm.register("email")} />
                {emailForm.formState.errors.email && (
                  <p className="mt-1 text-xs text-[var(--danger)]">{emailForm.formState.errors.email.message}</p>
                )}
              </div>
              {error && (
                <p className="rounded-[var(--radius)] bg-[var(--danger-soft)] px-3 py-2 text-sm text-[var(--danger)]">
                  {error}
                </p>
              )}
              <Button type="submit" className="w-full" size="lg" disabled={sending}>
                {sending ? "Отправляем…" : "Отправить код"}
              </Button>
            </form>
          ) : (
            <form className="space-y-3.5" onSubmit={resetForm.handleSubmit(onConfirm)}>
              <div>
                <label className="label-text" htmlFor="forgot-code">
                  Код из письма
                </label>
                <Input
                  id="forgot-code"
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  {...resetForm.register("code")}
                />
                {resetForm.formState.errors.code && (
                  <p className="mt-1 text-xs text-[var(--danger)]">{resetForm.formState.errors.code.message}</p>
                )}
              </div>
              <div>
                <label className="label-text" htmlFor="forgot-pass">
                  Новый пароль
                </label>
                <Input
                  id="forgot-pass"
                  type="password"
                  autoComplete="new-password"
                  {...resetForm.register("new_password")}
                />
                {resetForm.formState.errors.new_password && (
                  <p className="mt-1 text-xs text-[var(--danger)]">
                    {resetForm.formState.errors.new_password.message}
                  </p>
                )}
              </div>
              <div>
                <label className="label-text" htmlFor="forgot-pass2">
                  Подтверждение пароля
                </label>
                <Input
                  id="forgot-pass2"
                  type="password"
                  autoComplete="new-password"
                  {...resetForm.register("new_password_confirm")}
                />
                {resetForm.formState.errors.new_password_confirm && (
                  <p className="mt-1 text-xs text-[var(--danger)]">
                    {resetForm.formState.errors.new_password_confirm.message}
                  </p>
                )}
              </div>
              {error && (
                <p className="rounded-[var(--radius)] bg-[var(--danger-soft)] px-3 py-2 text-sm text-[var(--danger)]">
                  {error}
                </p>
              )}
              <Button type="submit" className="w-full" size="lg" disabled={sending}>
                {sending ? "Сохраняем…" : "Сбросить пароль"}
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

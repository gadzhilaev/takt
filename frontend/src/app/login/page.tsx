"use client";

import { AppIcon } from "@/components/ui/app-icon";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import Link from "next/link";
import { BrandLogo } from "@/components/brand-mark";

const schema = z.object({
  email: z.string().email("Введите корректный email"),
  password: z.string().min(1, "Введите пароль"),
});

export default function LoginPage() {
  const router = useRouter();
  const [show, setShow] = useState(false);
  const [error, setError] = useState("");
  const form = useForm({ resolver: zodResolver(schema), defaultValues: { email: "", password: "" } });

  async function onSubmit(values: z.infer<typeof schema>) {
    setError("");
    try {
      const res = await api<{ user: { must_change_password: boolean } }>("/api/v1/auth/login", {
        method: "POST",
        json: values,
      });
      if (res.user.must_change_password) router.push("/change-password");
      else router.push("/projects");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Ошибка входа");
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
          <BrandLogo className="h-9 w-auto max-w-[11.5rem]" title="Takt" />
        </div>
        <div className="surface-panel p-6 sm:p-7">
          <div className="mb-6">
            <h1 className="text-xl font-semibold tracking-tight">Вход</h1>
            <p className="mt-1.5 text-[13px] leading-snug text-muted">
              Войдите, чтобы открыть доску команды
            </p>
          </div>
          <form className="space-y-3.5" method="post" action="#" onSubmit={form.handleSubmit(onSubmit)}>
            <div>
              <label className="label-text" htmlFor="login-email">
                Email
              </label>
              <Input id="login-email" type="email" autoComplete="email" {...form.register("email")} />
            </div>
            <div>
              <label className="label-text" htmlFor="login-password">
                Пароль
              </label>
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
            {error && (
              <p className="rounded-[var(--radius)] bg-[var(--danger-soft)] px-3 py-2 text-sm text-[var(--danger)]" role="alert">
                {error}
              </p>
            )}
            <Button type="submit" className="w-full" size="lg" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting ? "Входим…" : "Войти"}
            </Button>
          </form>
          <p className="mt-5 text-center text-sm text-muted">
            Нет аккаунта?{" "}
            <Link href="/register" className="font-medium text-[var(--accent)]">
              Регистрация
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}

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

const schema = z
  .object({
    name: z.string().min(1, "Укажите имя"),
    email: z.string().email("Введите корректный email"),
    password: z.string().min(8, "Минимум 8 символов"),
    password_confirm: z.string().min(8, "Минимум 8 символов"),
  })
  .refine((v) => v.password === v.password_confirm, {
    message: "Пароли не совпадают",
    path: ["password_confirm"],
  });

export default function RegisterPage() {
  const router = useRouter();
  const [error, setError] = useState("");
  const form = useForm({
    resolver: zodResolver(schema),
    defaultValues: { name: "", email: "", password: "", password_confirm: "" },
  });

  async function onSubmit(values: z.infer<typeof schema>) {
    setError("");
    try {
      await api("/api/v1/auth/register", { method: "POST", json: values });
      router.push("/projects");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Ошибка регистрации");
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
            <h1 className="text-xl font-semibold tracking-tight">Регистрация</h1>
            <p className="mt-1.5 text-[13px] leading-snug text-muted">
              Создайте аккаунт и свой первый проект
            </p>
          </div>
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
            <Button type="submit" className="w-full" size="lg" disabled={form.formState.isSubmitting}>
              Зарегистрироваться
            </Button>
          </form>
          <p className="mt-5 text-center text-sm text-muted">
            Уже есть аккаунт?{" "}
            <Link href="/login" className="font-medium text-[var(--accent)]">
              Войти
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}

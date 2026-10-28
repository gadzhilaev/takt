"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Eye, EyeOff } from "lucide-react";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

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
      else router.push("/board");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Ошибка входа");
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-indigo-50 via-white to-slate-100 p-4 dark:from-slate-950 dark:via-slate-900 dark:to-slate-950">
      <div className="w-full max-w-md rounded-2xl border border-slate-200 bg-white p-8 shadow-xl dark:border-slate-800 dark:bg-slate-900">
        <h1 className="mb-2 text-2xl font-semibold">Вход в трекер</h1>
        <p className="mb-6 text-sm text-slate-500">Email и пароль от администратора</p>
        <form className="space-y-4" onSubmit={form.handleSubmit(onSubmit)}>
          <div>
            <label className="mb-1 block text-sm font-medium">Email</label>
            <Input type="email" autoComplete="email" {...form.register("email")} />
          </div>
          <div>
            <label className="mb-1 block text-sm font-medium">Пароль</label>
            <div className="relative">
              <Input
                type={show ? "text" : "password"}
                autoComplete="current-password"
                {...form.register("password")}
              />
              <button
                type="button"
                className="absolute right-2 top-2 text-slate-400"
                onClick={() => setShow((s) => !s)}
                aria-label={show ? "Скрыть пароль" : "Показать пароль"}
              >
                {show ? <EyeOff className="h-5 w-5" /> : <Eye className="h-5 w-5" />}
              </button>
            </div>
          </div>
          {error && <p className="text-sm text-red-600">{error}</p>}
          <Button type="submit" className="w-full">
            Войти
          </Button>
        </form>
        <p className="mt-6 text-center text-xs text-slate-500">Нет доступа? Обратитесь к администратору.</p>
      </div>
    </div>
  );
}

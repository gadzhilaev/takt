"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { PasswordInput } from "@/components/ui/password-input";

export default function ChangePasswordPage() {
  const router = useRouter();
  const [pwd, setPwd] = useState("");
  const [err, setErr] = useState("");

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr("");
    if (pwd.trim().length < 8) {
      setErr("Пароль не короче 8 символов");
      return;
    }
    try {
      await api("/api/v1/auth/force-change-password", { method: "POST", json: { new_password: pwd } });
      router.push("/login");
    } catch (e) {
      setErr(e instanceof Error ? e.message : "Не удалось сменить пароль");
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center p-4">
      <form onSubmit={submit} noValidate className="w-full max-w-md space-y-4 rounded-xl border p-6 shadow">
        <h1 className="text-xl font-semibold">Смените пароль</h1>
        <p className="text-sm text-muted">При первом входе нужно задать свой пароль</p>
        <PasswordInput
          value={pwd}
          onChange={(e) => setPwd(e.target.value)}
          placeholder="Новый пароль"
          autoComplete="new-password"
          minLength={8}
        />
        {err && <p className="text-sm text-[var(--danger)]">{err}</p>}
        <Button type="submit" className="w-full">
          Сохранить
        </Button>
      </form>
    </div>
  );
}

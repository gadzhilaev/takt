"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

export default function ProfilePage() {
  const qc = useQueryClient();
  const { data } = useQuery({ queryKey: ["me"], queryFn: () => api<{ user: { name: string; email: string } }>("/api/v1/auth/me") });
  const [name, setName] = useState("");
  const [current, setCurrent] = useState("");
  const [newPwd, setNewPwd] = useState("");

  useEffect(() => {
    if (data?.user) setName(data.user.name);
  }, [data?.user]);

  const saveName = useMutation({
    mutationFn: () => api("/api/v1/users/me", { method: "PATCH", json: { name } }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["me"] }),
  });

  async function changePassword(e: React.FormEvent) {
    e.preventDefault();
    await api("/api/v1/auth/change-password", {
      method: "POST",
      json: { current_password: current, new_password: newPwd },
    });
    setCurrent("");
    setNewPwd("");
    alert("Пароль изменён. Войдите снова.");
    window.location.href = "/login";
  }

  return (
    <div className="mx-auto max-w-lg space-y-8 overflow-y-auto overscroll-contain pb-6">
      <h1 className="text-2xl font-semibold">Профиль</h1>
      <section className="space-y-3 rounded-xl border p-4 dark:border-slate-800">
        <label className="block text-sm font-medium">Имя</label>
        <Input value={name} onChange={(e) => setName(e.target.value)} />
        <p className="text-xs text-slate-500">Email: {data?.user.email} (меняет администратор)</p>
        <Button onClick={() => saveName.mutate()}>Сохранить имя</Button>
      </section>
      <form onSubmit={changePassword} className="space-y-3 rounded-xl border p-4 dark:border-slate-800">
        <h2 className="font-medium">Смена пароля</h2>
        <Input type="password" placeholder="Текущий пароль" value={current} onChange={(e) => setCurrent(e.target.value)} />
        <Input type="password" placeholder="Новый пароль" value={newPwd} onChange={(e) => setNewPwd(e.target.value)} minLength={8} />
        <Button type="submit">Обновить пароль</Button>
      </form>
    </div>
  );
}

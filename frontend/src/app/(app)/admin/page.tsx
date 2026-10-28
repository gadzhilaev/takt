"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import Link from "next/link";
import { Copy, Plus } from "lucide-react";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { UserAvatar } from "@/components/user-avatar";

type AdminUser = {
  id: string;
  name: string;
  email: string;
  role: string;
  is_active: boolean;
  created_at: string;
  last_login_at: string | null;
  avatar_url: string | null;
};

function genPassword() {
  const chars = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%";
  let s = "";
  for (let i = 0; i < 16; i++) s += chars[Math.floor(Math.random() * chars.length)];
  return s;
}

export default function AdminPage() {
  const qc = useQueryClient();
  const [search, setSearch] = useState("");
  const [form, setForm] = useState({
    name: "",
    email: "",
    role: "member",
    password: genPassword(),
    must_change_password: true,
  });
  const [tempPwd, setTempPwd] = useState<string | null>(null);

  const { data } = useQuery({
    queryKey: ["admin-users", search],
    queryFn: () => api<{ items: AdminUser[] }>(`/api/v1/admin/users${search ? `?search=${encodeURIComponent(search)}` : ""}`),
  });

  const createUser = useMutation({
    mutationFn: () =>
      api<{ user: AdminUser; temporary_password: string | null }>("/api/v1/admin/users", {
        method: "POST",
        json: form,
      }),
    onSuccess: (res) => {
      setTempPwd(res.temporary_password ?? form.password);
      setForm({ name: "", email: "", role: "member", password: genPassword(), must_change_password: true });
      qc.invalidateQueries({ queryKey: ["admin-users"] });
    },
  });

  const users = data?.items ?? [];

  function copyLogin() {
    const site = window.location.origin;
    const text = `Адрес: ${site}\nEmail: ${form.email || "—"}\nПароль: ${tempPwd ?? form.password}`;
    navigator.clipboard.writeText(text);
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h1 className="text-2xl font-semibold">Админка · Пользователи</h1>
        <Link href="/admin/settings" className="text-sm text-indigo-600 hover:underline">
          Настройки команды →
        </Link>
      </div>
      <Input placeholder="Поиск по имени или email" value={search} onChange={(e) => setSearch(e.target.value)} />

      <div className="rounded-xl border p-4 dark:border-slate-800">
        <h2 className="mb-3 flex items-center gap-2 font-medium">
          <Plus className="h-4 w-4" /> Добавить пользователя
        </h2>
        <div className="grid gap-2 md:grid-cols-2">
          <Input placeholder="Имя" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          <Input placeholder="Email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
          <select
            className="rounded-lg border px-3 dark:bg-slate-900"
            value={form.role}
            onChange={(e) => setForm({ ...form, role: e.target.value })}
          >
            <option value="member">Участник</option>
            <option value="admin">Администратор</option>
          </select>
          <div className="flex gap-2">
            <Input
              value={form.password}
              onChange={(e) => setForm({ ...form, password: e.target.value })}
              aria-label="Пароль"
            />
            <Button type="button" variant="secondary" onClick={() => setForm({ ...form, password: genPassword() })}>
              Сгенерировать
            </Button>
          </div>
        </div>
        <label className="mt-2 flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={form.must_change_password}
            onChange={(e) => setForm({ ...form, must_change_password: e.target.checked })}
          />
          Потребовать смену пароля при первом входе
        </label>
        <div className="mt-3 flex flex-wrap gap-2">
          <Button onClick={() => createUser.mutate()} disabled={!form.name || !form.email}>
            Создать
          </Button>
          <Button variant="secondary" onClick={copyLogin}>
            <Copy className="h-4 w-4" /> Скопировать данные для входа
          </Button>
        </div>
        {tempPwd && (
          <p className="mt-2 text-sm text-amber-700 dark:text-amber-300">
            Временный пароль (показан один раз): <strong>{tempPwd}</strong>
          </p>
        )}
      </div>

      <div className="overflow-x-auto rounded-xl border dark:border-slate-800">
        <table className="min-w-full text-sm">
          <thead className="bg-slate-100 dark:bg-slate-900">
            <tr>
              {["", "Имя", "Email", "Роль", "Статус", "Создан", "Вход", ""].map((h) => (
                <th key={h} className="px-3 py-2 text-left">
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {users.map((u) => (
              <tr key={u.id} className="border-t dark:border-slate-800">
                <td className="px-3 py-2">
                  <UserAvatar name={u.name} avatarUrl={u.avatar_url} />
                </td>
                <td className="px-3 py-2">{u.name}</td>
                <td className="px-3 py-2">{u.email}</td>
                <td className="px-3 py-2">{u.role === "admin" ? "Админ" : "Участник"}</td>
                <td className="px-3 py-2">{u.is_active ? "Активен" : "Отключён"}</td>
                <td className="px-3 py-2">{u.created_at.slice(0, 10)}</td>
                <td className="px-3 py-2">{u.last_login_at?.slice(0, 10) ?? "—"}</td>
                <td className="px-3 py-2">
                  <Button
                    size="sm"
                    variant={u.is_active ? "destructive" : "secondary"}
                    onClick={async () => {
                      await api(`/api/v1/admin/users/${u.id}/${u.is_active ? "deactivate" : "activate"}`, {
                        method: "POST",
                      });
                      qc.invalidateQueries({ queryKey: ["admin-users"] });
                    }}
                  >
                    {u.is_active ? "Отключить" : "Включить"}
                  </Button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

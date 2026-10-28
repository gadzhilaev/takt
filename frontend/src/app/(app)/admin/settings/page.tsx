"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import type { Status } from "@/lib/types";

export default function AdminSettingsPage() {
  const qc = useQueryClient();
  const { data: team } = useQuery({
    queryKey: ["team"],
    queryFn: () => api<{ team_name: string }>("/api/v1/settings/team"),
  });
  const { data: statuses } = useQuery({
    queryKey: ["statuses"],
    queryFn: () => api<{ items: Status[] }>("/api/v1/settings/statuses"),
  });

  const saveTeam = useMutation({
    mutationFn: (team_name: string) => api("/api/v1/settings/team", { method: "PATCH", json: { team_name } }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["team"] }),
  });

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <Link href="/admin" className="text-sm font-medium text-[var(--accent)]">
          ← Пользователи
        </Link>
        <h1 className="text-2xl font-semibold">Настройки команды</h1>
      </div>
      <section className="rounded-xl border p-4 dark:border-slate-800">
        <label className="text-sm font-medium">Название команды</label>
        <div className="mt-2 flex gap-2">
          <Input defaultValue={team?.team_name} id="team-name" />
          <Button
            onClick={() => {
              const el = document.getElementById("team-name") as HTMLInputElement;
              saveTeam.mutate(el.value);
            }}
          >
            Сохранить
          </Button>
        </div>
      </section>
      <section className="rounded-xl border p-4 dark:border-slate-800">
        <h2 className="mb-3 font-medium">Статусы задач</h2>
        <ul className="space-y-2">
          {(statuses?.items ?? []).map((s) => (
            <li key={s.id} className="flex items-center gap-3 text-sm">
              <span className="h-3 w-3 rounded-full" style={{ background: s.color }} />
              {s.name}
              {s.is_done && <span className="text-xs text-slate-500">(завершающий)</span>}
            </li>
          ))}
        </ul>
        <p className="mt-2 text-xs text-slate-500">Редактирование цветов и порядка — через API /api/v1/settings/statuses</p>
      </section>
    </div>
  );
}

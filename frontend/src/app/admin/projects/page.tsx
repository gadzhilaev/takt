"use client";

import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";

type ProjectRow = {
  id: string;
  name: string;
  task_count: number;
  member_count: number;
  restricted: boolean;
  restriction_reason?: string | null;
  owner?: { email: string } | null;
};

export default function AdminProjectsPage() {
  const [q, setQ] = useState("");
  const [page, setPage] = useState(1);
  const qc = useQueryClient();
  const { data, isLoading } = useQuery({
    queryKey: ["platform-projects", q, page],
    queryFn: () => {
      const sp = new URLSearchParams({ page: String(page), page_size: "20" });
      if (q.trim()) sp.set("q", q.trim());
      return api<{ items: ProjectRow[]; total: number }>(`/api/v1/platform/projects?${sp}`);
    },
  });

  const restrict = useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) =>
      api(`/api/v1/platform/projects/${id}/restrict`, { method: "POST", json: { reason } }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["platform-projects"] }),
  });

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold tracking-tight">Проекты</h1>
      <p className="text-[13px] text-muted">Метаданные только — без тел задач.</p>
      <Input
        placeholder="Поиск"
        value={q}
        onChange={(e) => {
          setPage(1);
          setQ(e.target.value);
        }}
        className="max-w-sm"
      />
      {isLoading ? (
        <p className="text-sm text-muted">Загрузка…</p>
      ) : (
        <ul className="space-y-2">
          {(data?.items ?? []).map((p) => (
            <li key={p.id} className="rounded-[var(--radius)] border border-[var(--border)] bg-white p-4 text-[13px]">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div>
                  <p className="font-semibold">{p.name}</p>
                  <p className="text-muted">
                    задач: {p.task_count} · участников: {p.member_count}
                    {p.owner ? ` · владелец: ${p.owner.email}` : ""}
                  </p>
                  {p.restricted && <p className="text-[var(--danger)]">Ограничен: {p.restriction_reason}</p>}
                </div>
                <Button
                  type="button"
                  size="sm"
                  variant="secondary"
                  disabled={restrict.isPending}
                  onClick={() => {
                    const reason = window.prompt("Причина ограничения проекта");
                    if (reason && reason.trim().length >= 3) restrict.mutate({ id: p.id, reason: reason.trim() });
                  }}
                >
                  Ограничить
                </Button>
              </div>
            </li>
          ))}
        </ul>
      )}
      <div className="flex gap-2">
        <Button type="button" size="sm" variant="secondary" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
          Назад
        </Button>
        <Button type="button" size="sm" variant="secondary" onClick={() => setPage((p) => p + 1)}>
          Далее
        </Button>
      </div>
    </div>
  );
}

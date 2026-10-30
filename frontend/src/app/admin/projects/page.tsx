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

const PAGE_SIZE = 20;

export default function AdminProjectsPage() {
  const [q, setQ] = useState("");
  const [page, setPage] = useState(1);
  const qc = useQueryClient();
  const { data, isLoading } = useQuery({
    queryKey: ["platform-projects", q, page],
    queryFn: () => {
      const sp = new URLSearchParams({ page: String(page), page_size: String(PAGE_SIZE) });
      if (q.trim()) sp.set("q", q.trim());
      return api<{ items: ProjectRow[]; total: number }>(`/api/v1/platform/projects?${sp}`);
    },
  });

  const restrict = useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) =>
      api(`/api/v1/platform/projects/${id}/restrict`, { method: "POST", json: { reason } }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["platform-projects"] }),
  });

  const total = data?.total ?? 0;
  const pageCount = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const showPager = total > PAGE_SIZE;

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">Проекты</h1>
        <p className="mt-1 text-[13px] text-[#5a6573]">
          Только названия и счётчики. Названия и описания задач платформенный админ не видит.
        </p>
      </div>
      <Input
        placeholder="Поиск по названию"
        value={q}
        onChange={(e) => {
          setPage(1);
          setQ(e.target.value);
        }}
        className="max-w-sm"
      />
      {isLoading ? (
        <p className="text-sm text-[#5a6573]">Загрузка…</p>
      ) : (
        <ul className="space-y-2">
          {(data?.items ?? []).map((p) => (
            <li key={p.id} className="rounded-[var(--radius)] border border-[#dce2e7] bg-white p-4 text-[13px]">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div>
                  <p className="font-semibold text-[#202938]">{p.name}</p>
                  <p className="text-[#5a6573]">
                    задач: {p.task_count} · участников: {p.member_count}
                    {p.owner ? ` · владелец: ${p.owner.email}` : ""}
                  </p>
                  {p.restricted && (
                    <p className="text-[var(--danger)]">Ограничен: {p.restriction_reason}</p>
                  )}
                </div>
                <Button
                  type="button"
                  size="sm"
                  variant="secondary"
                  disabled={restrict.isPending}
                  onClick={() => {
                    const reason = window.prompt("Причина ограничения проекта");
                    if (reason && reason.trim().length >= 3) {
                      restrict.mutate({ id: p.id, reason: reason.trim() });
                    }
                  }}
                >
                  Ограничить
                </Button>
              </div>
            </li>
          ))}
        </ul>
      )}
      {showPager && (
        <div className="flex flex-wrap items-center gap-2">
          <Button
            type="button"
            size="sm"
            variant="secondary"
            disabled={page <= 1}
            onClick={() => setPage((p) => p - 1)}
          >
            Назад
          </Button>
          <span className="text-[12px] text-[#5a6573]">
            стр. {page} из {pageCount} · всего {total}
          </span>
          <Button
            type="button"
            size="sm"
            variant="secondary"
            disabled={page >= pageCount}
            onClick={() => setPage((p) => p + 1)}
          >
            Далее
          </Button>
        </div>
      )}
    </div>
  );
}

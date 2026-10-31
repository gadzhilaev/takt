"use client";

import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import { useSessionState } from "@/lib/use-session-state";

type Report = {
  id: string;
  reason_code: string;
  status: string;
  target_type: string;
  target_id: string;
  version: number;
  created_at?: string | null;
  assignee_id?: string | null;
};

const STATUS_ALL = "__all__";

const STATUS_LABELS: Record<string, string> = {
  open: "Открыта",
  in_review: "На проверке",
  resolved_warning: "Предупреждение",
  resolved_restriction: "Ограничение",
  rejected: "Отклонена",
  appealed: "Апелляция",
  closed: "Закрыта",
};

const TARGET_LABELS: Record<string, string> = {
  user: "Пользователь",
  project: "Проект",
  task: "Задача",
};

export default function AdminModerationPage() {
  const [status, setStatus] = useSessionState<string>("takt-admin-mod-status", "");
  const qc = useQueryClient();

  const { data, isLoading, error } = useQuery({
    queryKey: ["platform-moderation", status],
    queryFn: () => {
      const sp = new URLSearchParams({ page: "1", page_size: "50" });
      if (status) sp.set("status", status);
      return api<{ items: Report[] }>(`/api/v1/platform/moderation/reports?${sp}`);
    },
    placeholderData: keepPreviousData,
  });

  const decide = useMutation({
    mutationFn: ({
      id,
      action,
      version,
    }: {
      id: string;
      action: string;
      version: number;
    }) =>
      api(`/api/v1/platform/moderation/reports/${id}/decide`, {
        method: "POST",
        json: { action, expected_version: version },
      }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["platform-moderation"] }),
  });

  const items = data?.items ?? [];

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">Модерация</h1>
        <p className="mt-1 text-[13px] text-muted">
          Очередь жалоб. Решение фиксируется в журнале; повторное решение по устаревшей версии
          отклоняется.
        </p>
      </div>

      <Select
        aria-label="Статус жалобы"
        value={status || STATUS_ALL}
        onValueChange={(v) => setStatus(v === STATUS_ALL ? "" : v)}
        className="h-9 w-[14rem] max-w-full"
        options={[
          { value: STATUS_ALL, label: "Все статусы" },
          { value: "open", label: "Открыта" },
          { value: "in_review", label: "На проверке" },
          { value: "resolved_warning", label: "Предупреждение" },
          { value: "resolved_restriction", label: "Ограничение" },
          { value: "rejected", label: "Отклонена" },
          { value: "appealed", label: "Апелляция" },
          { value: "closed", label: "Закрыта" },
        ]}
      />

      {isLoading && <p className="text-sm text-muted">Загрузка…</p>}
      {error && <p className="text-sm text-[var(--danger)]">{(error as Error).message}</p>}
      {!isLoading && !error && items.length === 0 ? (
        <div className="rounded-[var(--radius)] border border-[var(--border)] bg-white px-4 py-8 text-center">
          <p className="text-[14px] font-medium">Жалоб нет</p>
          <p className="mt-1 text-[13px] text-muted">
            Когда появятся репорты от пользователей или системы — они отобразятся здесь.
          </p>
        </div>
      ) : null}

      {items.length > 0 ? (
        <div className="overflow-x-auto rounded-[var(--radius)] border border-[var(--border)] bg-white">
          <table className="w-full min-w-[760px] text-left text-[13px]">
            <thead className="border-b border-[var(--border)] text-muted">
              <tr>
                <th className="px-3 py-2 font-medium">Причина</th>
                <th className="px-3 py-2 font-medium">Цель</th>
                <th className="px-3 py-2 font-medium">Статус</th>
                <th className="px-3 py-2 font-medium">Создана</th>
                <th className="px-3 py-2 font-medium">Решение</th>
              </tr>
            </thead>
            <tbody>
              {items.map((r) => {
                const open = r.status === "open" || r.status === "in_review";
                return (
                  <tr key={r.id} className="border-b border-[var(--border)] last:border-0">
                    <td className="px-3 py-2 font-medium">{r.reason_code}</td>
                    <td className="px-3 py-2 text-muted">
                      {TARGET_LABELS[r.target_type] ?? r.target_type}
                      <span className="ml-1 font-mono text-[11px]">{r.target_id.slice(0, 8)}…</span>
                    </td>
                    <td className="px-3 py-2">{STATUS_LABELS[r.status] ?? r.status}</td>
                    <td className="px-3 py-2 tabular-nums text-muted">
                      {r.created_at ? new Date(r.created_at).toLocaleString("ru-RU") : "—"}
                    </td>
                    <td className="px-3 py-2">
                      {open ? (
                        <div className="flex flex-wrap gap-1.5">
                          <Button
                            type="button"
                            size="sm"
                            variant="secondary"
                            disabled={decide.isPending}
                            onClick={() =>
                              decide.mutate({ id: r.id, action: "close", version: r.version })
                            }
                          >
                            Закрыть
                          </Button>
                          <Button
                            type="button"
                            size="sm"
                            variant="secondary"
                            disabled={decide.isPending}
                            onClick={() =>
                              decide.mutate({ id: r.id, action: "reject", version: r.version })
                            }
                          >
                            Отклонить
                          </Button>
                          <Button
                            type="button"
                            size="sm"
                            variant="secondary"
                            disabled={decide.isPending}
                            onClick={() =>
                              decide.mutate({ id: r.id, action: "warn", version: r.version })
                            }
                          >
                            Предупредить
                          </Button>
                        </div>
                      ) : (
                        <span className="text-muted">—</span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      ) : null}
      {decide.isError ? (
        <p className="text-sm text-[var(--danger)]">{(decide.error as Error).message}</p>
      ) : null}
    </div>
  );
}

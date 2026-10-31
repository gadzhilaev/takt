"use client";

import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";

type AuditItem = {
  id: string;
  created_at?: string;
  action: string;
  details?: string | null;
  admin_id?: string;
  target_user_id?: string | null;
};

const ACTION_LABELS: Record<string, string> = {
  user_blocked: "Пользователь заблокирован",
  user_unblocked: "Пользователь разблокирован",
  user_updated: "Профиль пользователя изменён",
  user_deleted: "Пользователь удалён",
  platform_role_set: "Изменена роль платформы",
  project_restricted: "Проект ограничен",
  project_unrestricted: "Ограничение проекта снято",
  platform_setting: "Изменены настройки платформы",
};

function actionLabel(action: string): string {
  if (ACTION_LABELS[action]) return ACTION_LABELS[action];
  if (action.startsWith("moderation_")) return `Модерация: ${action.replace("moderation_", "")}`;
  return action;
}

function formatWhen(iso?: string): string {
  if (!iso) return "—";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleString("ru-RU", {
    day: "numeric",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export default function AdminSecurityPage() {
  const { data, isLoading, error, refetch, isFetching } = useQuery({
    queryKey: ["platform-audit"],
    queryFn: () => api<{ items: AuditItem[] }>("/api/v1/platform/security/audit?limit=200"),
  });

  const items = data?.items ?? [];

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold tracking-tight">Безопасность</h1>
          <p className="mt-1 text-[13px] text-muted">
            Роли платформы и журнал действий админов. Роли внутри доски сюда не входят.
          </p>
        </div>
        <Button
          type="button"
          size="sm"
          variant="secondary"
          disabled={isFetching}
          onClick={() => refetch()}
        >
          Обновить
        </Button>
      </div>

      <section className="rounded-[var(--radius)] border border-[var(--border)] bg-white p-4">
        <h2 className="text-[14px] font-semibold">Роли платформы</h2>
        <div className="mt-3 overflow-x-auto">
          <table className="w-full min-w-[480px] text-left text-[13px]">
            <thead className="border-b border-[var(--border)] text-muted">
              <tr>
                <th className="pb-2 pr-3 font-medium">Роль</th>
                <th className="pb-2 font-medium">Доступ</th>
              </tr>
            </thead>
            <tbody>
              <tr className="border-b border-[var(--border)]">
                <td className="py-2 pr-3 font-medium">Пользователь</td>
                <td className="py-2 text-muted">Только свои проекты, без /admin</td>
              </tr>
              <tr className="border-b border-[var(--border)]">
                <td className="py-2 pr-3 font-medium">Поддержка</td>
                <td className="py-2 text-muted">Смотрит пользователей и проекты</td>
              </tr>
              <tr className="border-b border-[var(--border)]">
                <td className="py-2 pr-3 font-medium">Модератор</td>
                <td className="py-2 text-muted">Жалобы и блокировки</td>
              </tr>
              <tr className="border-b border-[var(--border)]">
                <td className="py-2 pr-3 font-medium">Админ</td>
                <td className="py-2 text-muted">Настройки входов и ограничения проектов</td>
              </tr>
              <tr>
                <td className="py-2 pr-3 font-medium">Суперадмин</td>
                <td className="py-2 text-muted">Полный доступ, назначение ролей</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p className="mt-3 text-[12px] text-muted">
          Вход в админку — обычный /login. Ссылка в профиле появляется при роли платформы. Лимит
          попыток входа включён.
        </p>
      </section>

      <section className="rounded-[var(--radius)] border border-[var(--border)] bg-white p-4">
        <h2 className="text-[14px] font-semibold">Журнал действий</h2>
        {isLoading && <p className="mt-3 text-sm text-muted">Загрузка…</p>}
        {error && <p className="mt-3 text-sm text-[var(--danger)]">{(error as Error).message}</p>}
        {!isLoading && !error && items.length === 0 && (
          <p className="mt-3 text-[13px] text-muted">
            Пока пусто — записи появятся после блокировок, смены ролей и ограничений проектов.
          </p>
        )}
        {items.length > 0 ? (
          <div className="mt-3 overflow-x-auto">
            <table className="w-full min-w-[640px] text-left text-[13px]">
              <thead className="border-b border-[var(--border)] text-muted">
                <tr>
                  <th className="px-1 py-2 font-medium">Когда</th>
                  <th className="px-1 py-2 font-medium">Действие</th>
                  <th className="px-1 py-2 font-medium">Детали</th>
                </tr>
              </thead>
              <tbody>
                {items.map((a) => (
                  <tr key={a.id} className="border-b border-[var(--border)] last:border-0">
                    <td className="px-1 py-2 whitespace-nowrap tabular-nums text-muted">
                      {formatWhen(a.created_at)}
                    </td>
                    <td className="px-1 py-2 font-medium">{actionLabel(a.action)}</td>
                    <td className="px-1 py-2 text-muted">{a.details || "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : null}
      </section>
    </div>
  );
}

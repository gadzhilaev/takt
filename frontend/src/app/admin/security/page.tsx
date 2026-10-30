"use client";

import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";

type AuditItem = {
  id: string;
  created_at?: string;
  action: string;
  details?: string | null;
};

const ACTION_LABELS: Record<string, string> = {
  user_blocked: "Пользователь заблокирован",
  user_unblocked: "Пользователь разблокирован",
  platform_role_set: "Изменена роль платформы",
  project_restricted: "Проект ограничен",
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
  const { data, isLoading, error } = useQuery({
    queryKey: ["platform-audit"],
    queryFn: () => api<{ items: AuditItem[] }>("/api/v1/platform/security/audit"),
  });

  const items = data?.items ?? [];

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-semibold tracking-tight text-[#202938]">Безопасность</h1>
        <p className="mt-1 text-[13px] text-[#5a6573]">
          Кто из админов что менял на платформе. Роли проекта (владелец доски) сюда не входят.
        </p>
      </div>

      <section className="rounded-[var(--radius)] border border-[#dce2e7] bg-white p-4">
        <h2 className="text-[14px] font-semibold text-[#202938]">Роли платформы</h2>
        <ul className="mt-2 space-y-1.5 text-[13px] text-[#5a6573]">
          <li>
            <span className="font-medium text-[#202938]">Поддержка</span> — смотрит пользователей и
            проекты
          </li>
          <li>
            <span className="font-medium text-[#202938]">Модератор</span> — жалобы и блокировки
          </li>
          <li>
            <span className="font-medium text-[#202938]">Админ</span> — настройки входов и ограничения
          </li>
          <li>
            <span className="font-medium text-[#202938]">Суперадмин</span> — полный доступ (назначается
            вручную на сервере)
          </li>
        </ul>
        <p className="mt-3 text-[12px] text-[#5a6573]">
          Вход в админку — обычный /login. Ссылка появляется в профиле, если есть роль платформы.
          Лимит попыток входа включён. Двухфакторка для админов — следующий этап.
        </p>
      </section>

      <section className="rounded-[var(--radius)] border border-[#dce2e7] bg-white p-4">
        <h2 className="text-[14px] font-semibold text-[#202938]">Журнал действий</h2>
        {isLoading && <p className="mt-3 text-sm text-[#5a6573]">Загрузка…</p>}
        {error && (
          <p className="mt-3 text-sm text-[var(--danger)]">{(error as Error).message}</p>
        )}
        {!isLoading && !error && items.length === 0 && (
          <p className="mt-3 text-[13px] text-[#5a6573]">
            Пока пусто — записи появятся после блокировок, смены ролей и ограничений проектов.
          </p>
        )}
        {items.length > 0 && (
          <ul className="mt-3 space-y-0 text-[13px]">
            {items.map((a) => (
              <li
                key={a.id}
                className="flex flex-wrap items-baseline justify-between gap-2 border-b border-[#dce2e7] py-2.5 last:border-0"
              >
                <div>
                  <p className="font-medium text-[#202938]">{actionLabel(a.action)}</p>
                  {a.details ? (
                    <p className="mt-0.5 text-[12px] text-[#5a6573]">{a.details}</p>
                  ) : null}
                </div>
                <span className="shrink-0 tabular-nums text-[12px] text-[#5a6573]">
                  {formatWhen(a.created_at)}
                </span>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}

"use client";

import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

type Health = {
  backend?: string;
  database?: string;
  email?: { configured?: boolean; from?: string | null };
  web_push?: { configured?: boolean };
  fcm?: { enabled?: boolean; credentials_configured?: boolean };
  oauth?: Record<string, { enabled?: boolean; configured?: boolean }>;
  background_jobs?: { available?: boolean; note?: string };
};

function StatusPill({ ok, label }: { ok: boolean; label: string }) {
  return (
    <span
      className={cn(
        "inline-flex rounded-full px-2 py-0.5 text-[11px] font-semibold",
        ok ? "bg-[#e8f3ec] text-[#2f6b4f]" : "bg-[#f1f3f5] text-[#5a6573]"
      )}
    >
      {label}
    </span>
  );
}

function Row({
  title,
  hint,
  ok,
  detail,
  okLabel = "Работает",
  badLabel = "Не настроено",
}: {
  title: string;
  hint: string;
  ok: boolean;
  detail?: string | null;
  okLabel?: string;
  badLabel?: string;
}) {
  return (
    <li className="flex flex-wrap items-start justify-between gap-3 border-b border-[var(--border)] py-3 last:border-0">
      <div className="min-w-0">
        <p className="text-[14px] font-medium">{title}</p>
        <p className="mt-0.5 text-[12px] text-muted">{hint}</p>
        {detail ? <p className="mt-1 text-[12px]">{detail}</p> : null}
      </div>
      <StatusPill ok={ok} label={ok ? okLabel : badLabel} />
    </li>
  );
}

const OAUTH_LABELS: Record<string, string> = {
  apple: "Apple",
  vk: "VK ID",
  yandex: "Яндекс ID",
};

export default function AdminSystemPage() {
  const { data, isLoading, error, refetch, isFetching, dataUpdatedAt } = useQuery({
    queryKey: ["platform-health"],
    queryFn: () => api<Health>("/api/v1/platform/system/health"),
  });

  if (isLoading) return <p className="text-sm text-muted">Загрузка…</p>;
  if (error) return <p className="text-sm text-[var(--danger)]">{(error as Error).message}</p>;
  if (!data) return null;

  const oauthEntries = Object.entries(data.oauth ?? {});
  const coreOk = data.backend === "ok" && data.database === "ok";

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold tracking-tight">Система</h1>
          <p className="mt-1 text-[13px] text-muted">
            Состояние API, почты, пушей и OAuth. Секреты сюда не попадают.
          </p>
        </div>
        <div className="flex items-center gap-2">
          {dataUpdatedAt ? (
            <span className="text-[11px] text-muted">
              {new Date(dataUpdatedAt).toLocaleTimeString("ru-RU")}
            </span>
          ) : null}
          <Button
            type="button"
            size="sm"
            variant="secondary"
            disabled={isFetching}
            onClick={() => refetch()}
          >
            Проверить снова
          </Button>
        </div>
      </div>

      <div
        className={cn(
          "rounded-[var(--radius)] border px-4 py-3 text-[13px]",
          coreOk
            ? "border-[#cfe3d6] bg-[#f3faf6] text-[#2f6b4f]"
            : "border-[#f0d6d6] bg-[#fdf6f6] text-[var(--danger)]"
        )}
      >
        {coreOk
          ? "Ядро в порядке: API и база данных отвечают."
          : "Проблема с ядром: проверьте API или PostgreSQL."}
      </div>

      <section className="rounded-[var(--radius)] border border-[var(--border)] bg-white px-4">
        <ul>
          <Row
            title="Сервер API"
            hint="Backend отвечает на запросы"
            ok={data.backend === "ok"}
          />
          <Row
            title="База данных"
            hint="PostgreSQL доступна"
            ok={data.database === "ok"}
          />
          <Row
            title="Почта (SMTP)"
            hint="Коды регистрации, сброс пароля, приглашения"
            ok={Boolean(data.email?.configured)}
            detail={data.email?.from ? `Отправитель: ${data.email.from}` : null}
          />
          <Row
            title="Web Push"
            hint="Уведомления в браузере"
            ok={Boolean(data.web_push?.configured)}
          />
          <Row
            title="Push в приложении (FCM)"
            hint="Уведомления на телефоне через Firebase"
            ok={Boolean(data.fcm?.enabled && data.fcm?.credentials_configured)}
          />
        </ul>
      </section>

      <section className="rounded-[var(--radius)] border border-[var(--border)] bg-white p-4">
        <h2 className="text-[14px] font-semibold">Вход через соцсети</h2>
        <p className="mt-1 text-[12px] text-muted">
          «Включён» = credentials есть и метод не выключен в настройках платформы.
        </p>
        <ul className="mt-2">
          {oauthEntries.map(([key, v]) => {
            const ready = Boolean(v.enabled && v.configured);
            return (
              <li
                key={key}
                className="flex items-center justify-between gap-3 border-b border-[var(--border)] py-2.5 last:border-0"
              >
                <span className="text-[13px]">{OAUTH_LABELS[key] ?? key}</span>
                <StatusPill
                  ok={ready}
                  label={ready ? "Включён" : v.configured ? "Выключен" : "Нет credentials"}
                />
              </li>
            );
          })}
        </ul>
      </section>

      <section className="rounded-[var(--radius)] border border-[var(--border)] bg-white p-4">
        <h2 className="text-[14px] font-semibold">Фоновые задачи</h2>
        <p className="mt-2 text-[13px] text-muted">
          {data.background_jobs?.note ??
            "Отдельной очереди ошибок пока нет — показатель не придумываем."}
        </p>
        <p className="mt-2">
          <StatusPill ok={false} label="Очередь не подключена" />
        </p>
      </section>
    </div>
  );
}

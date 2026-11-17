import { AppIcon } from "@/components/ui/app-icon";
import { cn } from "@/lib/utils";

const CARD =
  "overflow-hidden rounded-[var(--radius-lg)] border border-[var(--border)] bg-[var(--surface)] shadow-[0_12px_40px_rgba(32,41,56,0.08)] dark:shadow-[0_12px_40px_rgba(0,0,0,0.35)]";

/** Шаг 1: утреннее напоминание с кнопками ответа и расписание ритма. */
export function LandingMorningDemo({ className }: { className?: string }) {
  return (
    <div className={cn("space-y-3", className)} role="img" aria-label="Утреннее уведомление Takt с кнопками ответа">
      <div className={cn(CARD, "p-3.5")}>
        <div className="flex items-start gap-3">
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[var(--radius)] bg-[var(--accent)] text-[var(--accent-fg)]">
            <AppIcon name="circle-check" size={18} />
          </span>
          <div className="min-w-0 flex-1">
            <div className="flex items-baseline justify-between gap-2">
              <p className="truncate text-[13px] font-semibold text-[var(--foreground)]">Takt · Чек-ин</p>
              <span className="shrink-0 text-[11px] text-muted">9:00</span>
            </div>
            <p className="mt-0.5 text-[13px] text-[var(--foreground)]">Обновить раздел «Поступление» на сайте</p>
            <p className="text-[12px] text-muted">Приёмная кампания</p>
            <div className="mt-2.5 flex flex-wrap gap-1.5">
              <span className="rounded-full bg-[var(--success)] px-3 py-1 text-[12px] font-semibold text-white">Сделал</span>
              <span className="rounded-full border border-[var(--border)] bg-[var(--surface-2)] px-3 py-1 text-[12px] font-semibold text-[var(--muted-fg)]">
                В работе
              </span>
              <span className="rounded-full border border-[var(--border)] bg-[var(--surface-2)] px-3 py-1 text-[12px] font-semibold text-[var(--muted-fg)]">
                Застрял
              </span>
            </div>
          </div>
        </div>
      </div>
      <div className={cn(CARD, "flex items-center gap-3 px-4 py-3")}>
        <AppIcon name="timer" size={18} className="shrink-0 text-[var(--accent)]" />
        <div className="min-w-0 flex-1">
          <p className="text-[13px] font-semibold text-[var(--foreground)]">Ежедневный чек-ин</p>
          <p className="text-[12px] text-muted">Пн–Пт в 9:00 · настраивается в проекте</p>
        </div>
        <span className="rounded-full bg-[var(--accent-soft)] px-2.5 py-1 text-[11px] font-medium text-[var(--accent)]">
          Включён
        </span>
      </div>
    </div>
  );
}

/** Шаг 2: ответы сами переносят задачи и пишут историю. */
export function LandingAutoMoveDemo({ className }: { className?: string }) {
  const rows = [
    { title: "Подготовить список абитуриентов", answer: "Сделал", from: "В работе", to: "Готово", tone: "var(--success)" },
    { title: "Обновить раздел «Поступление»", answer: "В работе", from: "К выполнению", to: "В работе", tone: "var(--accent)" },
    { title: "Сверить оригиналы аттестатов", answer: "Застрял", from: "остаётся в «В работе»", to: "помечена «Застряла»", tone: "var(--warning)" },
  ];
  return (
    <div className={cn(CARD, className)} role="img" aria-label="Ответы на чек-ин сами переносят задачи">
      <div className="border-b border-[var(--border)] px-4 py-3">
        <p className="text-[13px] font-semibold text-[var(--foreground)]">История изменений</p>
        <p className="text-[12px] text-muted">Никто не двигает карточки вручную</p>
      </div>
      <ul className="divide-y divide-[var(--border)]">
        {rows.map((r) => (
          <li key={r.title} className="px-4 py-3">
            <p className="text-[13px] font-medium text-[var(--foreground)]">{r.title}</p>
            <p className="mt-1 flex flex-wrap items-center gap-x-1.5 gap-y-1 text-[12px] text-muted">
              <span
                className="rounded-full px-2 py-0.5 text-[11px] font-semibold text-white"
                style={{ background: r.tone }}
              >
                {r.answer}
              </span>
              <span>{r.from}</span>
              <AppIcon name="chevron-right" size={12} className="shrink-0" />
              <span className="font-medium text-[var(--foreground)]">{r.to}</span>
            </p>
          </li>
        ))}
      </ul>
    </div>
  );
}

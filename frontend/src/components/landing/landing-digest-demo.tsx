import { cn } from "@/lib/utils";

function Stat({ value, label, tone }: { value: string | number; label: string; tone?: string }) {
  return (
    <div className="rounded-[var(--radius)] border border-[var(--border)] bg-[var(--surface)] px-3 py-2.5">
      <div className={cn("text-xl font-semibold tabular-nums", tone)}>{value}</div>
      <div className="mt-0.5 text-[11px] text-muted">{label}</div>
    </div>
  );
}

/** Статичный макет пятничной сводки — те же блоки, что в реальном экране «Сводка». */
export function LandingDigestDemo({ className }: { className?: string }) {
  return (
    <div
      className={cn(
        "overflow-hidden rounded-[var(--radius-lg)] border border-[var(--border)] bg-[var(--kanban-board-bg)] shadow-[0_12px_40px_rgba(32,41,56,0.08)] dark:shadow-[0_12px_40px_rgba(0,0,0,0.35)]",
        className
      )}
      role="img"
      aria-label="Пример сводки за неделю: сделано, застряло, узкое место"
    >
      <div className="flex items-center justify-between gap-3 border-b border-[var(--border)] bg-[var(--surface)] px-4 py-3">
        <div className="min-w-0">
          <p className="truncate text-[13px] font-semibold text-[var(--foreground)]">Сводка · Приёмная кампания</p>
          <p className="text-[12px] text-muted">Неделя, пятница 18:00</p>
        </div>
        <span className="shrink-0 rounded-full bg-[var(--accent-soft)] px-2.5 py-1 text-[11px] font-medium text-[var(--accent)]">
          Пример
        </span>
      </div>
      <div className="space-y-2.5 p-3 sm:p-4">
        <div className="grid grid-cols-3 gap-2">
          <Stat value={14} label="сделано" tone="text-[var(--success)]" />
          <Stat value={2} label="застряло" tone="text-[var(--warning)]" />
          <Stat value="86%" label="ответы на чек-ин" />
        </div>
        <section className="rounded-[var(--radius)] border border-[var(--border)] bg-[var(--surface)]">
          <h3 className="border-b border-[var(--border)] px-3 py-2 text-[13px] font-semibold">
            Застряло <span className="ml-1 text-xs font-normal text-muted">2</span>
          </h3>
          <div className="divide-y divide-[var(--border)]">
            <div className="px-3 py-2.5">
              <p className="text-[13px] font-medium text-[var(--foreground)]">Сверить оригиналы аттестатов</p>
              <p className="mt-0.5 text-xs text-muted">2 дня · Е. Крылова</p>
              <p className="mt-1 border-l-2 border-[var(--warning)] pl-1.5 text-xs text-[var(--foreground)]/85">
                Ждём документы от двух школ
              </p>
            </div>
            <div className="px-3 py-2.5">
              <p className="text-[13px] font-medium text-[var(--foreground)]">Опубликовать приказ о зачислении</p>
              <p className="mt-0.5 text-xs text-muted">1 день · М. Ильин</p>
            </div>
          </div>
        </section>
        <section className="rounded-[var(--radius)] border border-[var(--border)] bg-[var(--surface)] px-3 py-2.5">
          <h3 className="text-[13px] font-semibold">Узкое место</h3>
          <p className="mt-1 text-[12px] leading-relaxed text-muted">
            Дольше всего задачи ждут в столбце{" "}
            <span className="font-medium text-[var(--foreground)]">«На проверке»</span> — в среднем 3,5 дня.
          </p>
        </section>
      </div>
    </div>
  );
}

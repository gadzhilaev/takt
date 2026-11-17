"use client";

import { useState } from "react";
import { AppIcon } from "@/components/ui/app-icon";
import { cn } from "@/lib/utils";

type Answer = "done" | "in_progress" | "blocked";

const OPTIONS: { value: Answer; label: string; icon: "circle-check" | "status" | "alert" }[] = [
  { value: "done", label: "Сделал", icon: "circle-check" },
  { value: "in_progress", label: "В работе", icon: "status" },
  { value: "blocked", label: "Застрял", icon: "alert" },
];

/** Те же цвета выбранного ответа, что и в реальной форме чек-ина. */
const ANSWER_STYLE: Record<Answer, string> = {
  done: "border-[var(--success)] bg-[var(--success)] text-white",
  in_progress: "border-[var(--accent)] bg-[var(--accent)] text-[var(--accent-fg)]",
  blocked: "border-[var(--warning)] bg-[var(--warning)] text-white",
};

const TASKS: { id: string; title: string; meta: string; initial: Answer | null }[] = [
  { id: "t1", title: "Подготовить список абитуриентов", meta: "Приёмная кампания · до пт", initial: "done" },
  { id: "t2", title: "Обновить раздел «Поступление» на сайте", meta: "Важно · до ср", initial: "in_progress" },
  { id: "t3", title: "Согласовать расписание консультаций", meta: "Обычная", initial: null },
];

/** Интерактивный макет утреннего чек-ина — собран из тех же элементов, что и в приложении. */
export function LandingCheckinDemo({ className }: { className?: string }) {
  const [picked, setPicked] = useState<Record<string, Answer | null>>(() =>
    Object.fromEntries(TASKS.map((t) => [t.id, t.initial]))
  );
  const answered = Object.values(picked).filter(Boolean).length;

  return (
    <div
      className={cn(
        "overflow-hidden rounded-[var(--radius-lg)] border border-[var(--border)] bg-[var(--surface)] shadow-[0_12px_40px_rgba(32,41,56,0.08)] dark:shadow-[0_12px_40px_rgba(0,0,0,0.35)]",
        className
      )}
    >
      <div className="flex items-center gap-3 border-b border-[var(--border)] bg-[var(--accent-soft)] px-4 py-3">
        <AppIcon name="circle-check" size={18} className="shrink-0 text-[var(--accent)]" />
        <div className="min-w-0 flex-1">
          <p className="truncate text-[13px] font-semibold text-[var(--foreground)]">Чек-ин на сегодня</p>
          <p className="truncate text-[12px] text-muted">Приёмная комиссия · 9:00</p>
        </div>
        <span className="rounded-full bg-[var(--surface)] px-2.5 py-1 text-[11px] font-medium tabular-nums text-[var(--accent)]">
          {answered} из {TASKS.length}
        </span>
      </div>
      <ul className="divide-y divide-[var(--border)]">
        {TASKS.map((task) => (
          <li key={task.id} className="px-4 py-3">
            <p className="text-[14px] font-medium leading-snug text-[var(--foreground)]">{task.title}</p>
            <p className="mt-0.5 text-[12px] text-muted">{task.meta}</p>
            <div className="mt-2.5 grid grid-cols-3 gap-1.5" role="group" aria-label={`Ответ: ${task.title}`}>
              {OPTIONS.map((o) => {
                const on = picked[task.id] === o.value;
                return (
                  <button
                    key={o.value}
                    type="button"
                    aria-pressed={on}
                    onClick={() => setPicked((p) => ({ ...p, [task.id]: o.value }))}
                    className={cn(
                      "inline-flex h-9 items-center justify-center gap-1 rounded-[var(--radius)] border px-1.5 text-[12px] font-semibold transition-colors",
                      on
                        ? ANSWER_STYLE[o.value]
                        : "border-[var(--border)] bg-[var(--surface)] text-[var(--muted-fg)] hover:bg-[var(--surface-2)]"
                    )}
                  >
                    <AppIcon name={o.icon} size={14} className="shrink-0" />
                    <span className="truncate">{o.label}</span>
                  </button>
                );
              })}
            </div>
          </li>
        ))}
      </ul>
      <div className="flex items-center justify-between gap-3 border-t border-[var(--border)] bg-[var(--surface-2)] px-4 py-2.5">
        <p className="text-[12px] text-muted">Нажмите ответ — доска обновится сама</p>
        <span className="rounded-[var(--radius)] bg-[var(--accent)] px-3 py-1.5 text-[12px] font-semibold text-[var(--accent-fg)]">
          Отправить
        </span>
      </div>
    </div>
  );
}

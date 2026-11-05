"use client";

import { AppIcon } from "@/components/ui/app-icon";
import { Button } from "@/components/ui/button";
import { Dialog } from "@/components/ui/dialog";
import { Select } from "@/components/ui/select";
import {
  addMonths,
  eachDayOfInterval,
  endOfMonth,
  endOfWeek,
  format,
  isSameDay,
  isSameMonth,
  startOfMonth,
  startOfWeek,
} from "date-fns";
import { ru } from "date-fns/locale";
import { useMemo, useState } from "react";
import { cn } from "@/lib/utils";

const WEEKDAYS = ["пн", "вт", "ср", "чт", "пт", "сб", "вс"];

function pad(n: number) {
  return String(n).padStart(2, "0");
}

function roundMinutes(m: number, step = 5) {
  return Math.min(55, Math.round(m / step) * step);
}

function formatDisplay(d: Date) {
  return `${pad(d.getDate())}.${pad(d.getMonth() + 1)}.${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function DateTimePickerField({
  valueIso,
  onChange,
  id,
  placeholder = "Дата и время",
  className,
}: {
  valueIso: string | null | undefined;
  onChange: (iso: string | null) => void;
  id?: string;
  placeholder?: string;
  className?: string;
}) {
  const value = valueIso ? new Date(valueIso) : null;
  const valid = value && !Number.isNaN(value.getTime()) ? value : null;
  const [open, setOpen] = useState(false);
  const [month, setMonth] = useState(() => valid ?? new Date());
  const [day, setDay] = useState<Date>(() => valid ?? new Date());
  const [hour, setHour] = useState(() => valid?.getHours() ?? 18);
  const [minute, setMinute] = useState(() => roundMinutes(valid?.getMinutes() ?? 0));

  function openPicker() {
    const base = valid ?? new Date();
    const next = new Date(base);
    if (!valid) {
      next.setDate(next.getDate() + 1);
      next.setHours(18, 0, 0, 0);
    }
    setMonth(next);
    setDay(next);
    setHour(next.getHours());
    setMinute(roundMinutes(next.getMinutes()));
    setOpen(true);
  }

  const days = useMemo(() => {
    const start = startOfWeek(startOfMonth(month), { weekStartsOn: 1 });
    const end = endOfWeek(endOfMonth(month), { weekStartsOn: 1 });
    return eachDayOfInterval({ start, end });
  }, [month]);

  const hourOpts = useMemo(
    () => Array.from({ length: 24 }, (_, h) => ({ value: String(h), label: pad(h) })),
    []
  );
  const minuteOpts = useMemo(
    () =>
      Array.from({ length: 12 }, (_, i) => {
        const m = i * 5;
        return { value: String(m), label: pad(m) };
      }),
    []
  );

  function apply() {
    const next = new Date(day.getFullYear(), day.getMonth(), day.getDate(), hour, minute, 0, 0);
    onChange(next.toISOString());
    setOpen(false);
  }

  function clear() {
    onChange(null);
    setOpen(false);
  }

  return (
    <>
      <div className={cn("flex items-center gap-2", className)}>
        <button
          type="button"
          id={id}
          onClick={openPicker}
          className={cn(
            "field flex h-10 min-w-0 flex-1 items-center justify-between gap-2 px-3 text-left text-sm",
            "border-[var(--border)] bg-[var(--surface)]",
            valid ? "text-foreground" : "text-muted"
          )}
        >
          <span className="truncate">{valid ? formatDisplay(valid) : placeholder}</span>
          <AppIcon name="timer" size={16} className="shrink-0 opacity-60" />
        </button>
        {valid ? (
          <Button type="button" size="sm" variant="ghost" onClick={() => onChange(null)}>
            Убрать
          </Button>
        ) : null}
      </div>

      <Dialog open={open} onOpenChange={setOpen} title="Срок выполнения" centerTitle className="w-[min(100%-1.5rem,22rem)]">
        <div className="space-y-3">
          <div className="flex items-center justify-between gap-2">
            <button
              type="button"
              className="rounded p-1.5 text-muted hover:bg-[var(--surface-2)] hover:text-foreground"
              aria-label="Предыдущий месяц"
              onClick={() => setMonth((m) => addMonths(m, -1))}
            >
              <AppIcon name="chevron-left" size={18} />
            </button>
            <p className="text-sm font-semibold capitalize text-foreground">
              {format(month, "LLLL yyyy", { locale: ru })}
            </p>
            <button
              type="button"
              className="rounded p-1.5 text-muted hover:bg-[var(--surface-2)] hover:text-foreground"
              aria-label="Следующий месяц"
              onClick={() => setMonth((m) => addMonths(m, 1))}
            >
              <AppIcon name="chevron-right" size={18} />
            </button>
          </div>

          <div className="grid grid-cols-7 gap-0.5 text-center text-[11px] font-medium text-muted">
            {WEEKDAYS.map((w) => (
              <div key={w} className="py-1">
                {w}
              </div>
            ))}
          </div>
          <div className="grid grid-cols-7 gap-0.5">
            {days.map((d) => {
              const inMonth = isSameMonth(d, month);
              const selected = isSameDay(d, day);
              const today = isSameDay(d, new Date());
              return (
                <button
                  key={d.toISOString()}
                  type="button"
                  onClick={() => {
                    setDay(d);
                    if (!isSameMonth(d, month)) setMonth(d);
                  }}
                  className={cn(
                    "flex h-9 items-center justify-center rounded-[var(--radius-sm)] text-sm tabular-nums",
                    !inMonth && "text-muted/50",
                    inMonth && !selected && "text-foreground hover:bg-[var(--surface-2)]",
                    selected && "bg-[var(--accent)] font-semibold text-[var(--accent-fg)]",
                    today && !selected && "ring-1 ring-inset ring-[var(--accent)]"
                  )}
                >
                  {d.getDate()}
                </button>
              );
            })}
          </div>

          <div className="grid grid-cols-2 gap-2">
            <div>
              <label className="label-text" htmlFor={`${id ?? "due"}-hour`}>
                Часы
              </label>
              <Select
                id={`${id ?? "due"}-hour`}
                aria-label="Часы"
                value={String(hour)}
                onValueChange={(v) => setHour(Number(v))}
                options={hourOpts}
              />
            </div>
            <div>
              <label className="label-text" htmlFor={`${id ?? "due"}-minute`}>
                Минуты
              </label>
              <Select
                id={`${id ?? "due"}-minute`}
                aria-label="Минуты"
                value={String(minute)}
                onValueChange={(v) => setMinute(Number(v))}
                options={minuteOpts}
              />
            </div>
          </div>

          <div className="flex gap-2 pt-1">
            {valid ? (
              <Button type="button" variant="ghost" className="flex-1" onClick={clear}>
                Убрать
              </Button>
            ) : null}
            <Button type="button" className="flex-1" onClick={apply}>
              Готово
            </Button>
          </div>
        </div>
      </Dialog>
    </>
  );
}

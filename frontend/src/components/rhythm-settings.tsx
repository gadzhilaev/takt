"use client";

import { Select } from "@/components/ui/select";
import {
  WEEKDAYS,
  timeOptions,
  timezoneOptions,
  toggleDay,
  type RhythmSettings,
} from "@/lib/rhythm";
import { cn } from "@/lib/utils";

/** Настройки ритма проекта (для администратора). */
export function RhythmSettingsFields({
  value,
  onChange,
}: {
  value: RhythmSettings;
  onChange: (next: RhythmSettings) => void;
}) {
  return (
    <div className="rounded-[var(--radius)] border border-hairline px-3 py-2.5">
      <label className="flex cursor-pointer items-start gap-2.5">
        <input
          type="checkbox"
          className="mt-0.5 h-4 w-4 accent-[var(--accent)]"
          checked={value.enabled}
          onChange={(e) => onChange({ ...value, enabled: e.target.checked })}
        />
        <span className="min-w-0">
          <span className="block text-sm font-medium text-foreground">Ежедневный чек-ин</span>
          <span className="mt-0.5 block text-xs leading-snug text-muted">
            Каждый получит вопрос по своим задачам и ответит одним нажатием — доска обновится сама.
          </span>
        </span>
      </label>
      {value.enabled && (
        <div className="mt-3 space-y-2.5 pl-6">
          <div className="grid grid-cols-2 gap-2">
            <div>
              <span className="label-text">Время</span>
              <Select
                aria-label="Время чек-ина"
                value={value.time}
                onValueChange={(time) => onChange({ ...value, time })}
                options={timeOptions(value.time)}
              />
            </div>
            <div>
              <span className="label-text">Часовой пояс</span>
              <Select
                aria-label="Часовой пояс"
                value={value.timezone}
                onValueChange={(timezone) => onChange({ ...value, timezone })}
                options={timezoneOptions(value.timezone)}
              />
            </div>
          </div>
          <div>
            <span className="label-text">Дни</span>
            <div className="flex flex-wrap gap-1" role="group" aria-label="Дни чек-ина">
              {WEEKDAYS.map((d) => {
                const on = value.days.includes(d.value);
                return (
                  <button
                    key={d.value}
                    type="button"
                    aria-pressed={on}
                    onClick={() => onChange({ ...value, days: toggleDay(value.days, d.value) })}
                    className={cn(
                      "h-8 min-w-[2.5rem] rounded-[var(--radius)] border px-2 text-xs font-medium",
                      on
                        ? "border-[var(--accent)] bg-[var(--accent)] text-[var(--accent-fg)]"
                        : "border-hairline text-muted hover:bg-[var(--surface-2)]"
                    )}
                  >
                    {d.short}
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export type DigestSettings = { daily: boolean; weekly: boolean; time: string };

export const DEFAULT_DIGEST: DigestSettings = { daily: false, weekly: true, time: "18:00" };

/** Расписание сводки руководителю (для администратора). */
export function DigestSettingsFields({
  value,
  onChange,
}: {
  value: DigestSettings;
  onChange: (next: DigestSettings) => void;
}) {
  const box = (checked: boolean, label: string, key: "daily" | "weekly") => (
    <label className="flex cursor-pointer items-center gap-2 text-sm text-foreground">
      <input
        type="checkbox"
        className="h-4 w-4 accent-[var(--accent)]"
        checked={checked}
        onChange={(e) => onChange({ ...value, [key]: e.target.checked })}
      />
      {label}
    </label>
  );
  return (
    <div className="rounded-[var(--radius)] border border-hairline px-3 py-2.5">
      <span className="block text-sm font-medium text-foreground">Сводка руководителю</span>
      <span className="mt-0.5 block text-xs leading-snug text-muted">
        Что сделано, что застряло и где узкое место — в уведомлениях администраторам и подписчикам.
      </span>
      <div className="mt-2.5 flex flex-wrap items-center gap-x-4 gap-y-2">
        {box(value.weekly, "По пятницам", "weekly")}
        {box(value.daily, "Каждый день", "daily")}
        <div className="ml-auto w-28">
          <Select
            aria-label="Время сводки"
            value={value.time}
            onValueChange={(time) => onChange({ ...value, time })}
            options={timeOptions(value.time)}
          />
        </div>
      </div>
    </div>
  );
}

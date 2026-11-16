"use client";

import { useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { AppIcon } from "@/components/ui/app-icon";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { api, messageFromApiError } from "@/lib/api";
import { formatDueChip, isDueOverdue } from "@/lib/format-due-date";
import {
  ANSWER_OPTIONS,
  REASON_MAX,
  answeredCount,
  buildAnswers,
  initialSelection,
  type Checkin,
  type CheckinAnswer,
  type Selection,
} from "@/lib/rhythm";
import { urgencyLabel } from "@/lib/urgency";
import { cn } from "@/lib/utils";

/** Выбранный ответ — заливка цветом ответа, чтобы выбор читался сразу. */
const ANSWER_STYLE: Record<CheckinAnswer, string> = {
  done: "border-[var(--success)] bg-[var(--success)] text-white",
  in_progress: "border-[var(--accent)] bg-[var(--accent)] text-[var(--accent-fg)]",
  blocked: "border-[var(--warning)] bg-[var(--warning)] text-white",
};

const ANSWER_ICON: Record<CheckinAnswer, "circle-check" | "status" | "alert"> = {
  done: "circle-check",
  in_progress: "status",
  blocked: "alert",
};

/** Ответ на чек-ин: по задаче — одна кнопка из трёх, «Застрял» — короткая причина. */
export function CheckinForm({
  checkin,
  onDone,
}: {
  checkin: Checkin;
  onDone?: (updated: Checkin) => void;
}) {
  const qc = useQueryClient();
  const [selection, setSelection] = useState<Selection>(() => initialSelection(checkin));
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");
  const now = new Date();
  const answers = buildAnswers(checkin, selection);
  const answered = answeredCount(checkin, selection);

  function pick(taskId: string, answer: CheckinAnswer) {
    setSelection((prev) => ({ ...prev, [taskId]: { ...prev[taskId], answer } }));
  }

  async function submit() {
    if (!answers.length) {
      onDone?.(checkin);
      return;
    }
    setBusy(true);
    setErr("");
    try {
      const res = await api<{ checkin: Checkin }>(`/api/v1/rhythm/checkins/${checkin.id}/answer`, {
        method: "POST",
        json: { answers },
      });
      qc.invalidateQueries({ queryKey: ["rhythm", "current"] });
      qc.invalidateQueries({ queryKey: ["tasks"] });
      onDone?.(res.checkin);
    } catch (e) {
      setErr(messageFromApiError(e) || "Не удалось сохранить ответ");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-3">
      <ul className="space-y-2.5">
        {checkin.items.map((item) => {
          const sel = selection[item.task_id];
          const dueLabel = formatDueChip(item.due_date, now);
          const overdue = isDueOverdue(item.due_date, now);
          return (
            <li
              key={item.task_id}
              className="rounded-[var(--radius)] border border-hairline bg-[var(--surface)] p-3"
            >
              <div className="flex items-start gap-2">
                <p className="min-w-0 flex-1 text-sm font-semibold leading-snug text-foreground">
                  {item.title}
                </p>
              </div>
              <p className="mt-1 flex flex-wrap gap-x-2 text-xs text-muted">
                <span>{urgencyLabel(item.priority)}</span>
                {item.status && <span>· {item.status.name}</span>}
                {dueLabel && (
                  <span className={cn(overdue && "text-[var(--danger)]")}>
                    · {overdue ? `просрочено ${dueLabel}` : dueLabel}
                  </span>
                )}
              </p>
              <div className="mt-2.5 grid grid-cols-3 gap-1.5" role="radiogroup" aria-label={item.title}>
                {ANSWER_OPTIONS.map((opt) => {
                  const active = sel?.answer === opt.value;
                  return (
                    <button
                      key={opt.value}
                      type="button"
                      role="radio"
                      aria-checked={active}
                      disabled={busy}
                      onClick={() => pick(item.task_id, opt.value)}
                      className={cn(
                        "flex min-h-[44px] items-center justify-center gap-1.5 rounded-[var(--radius)] border px-2 text-sm font-medium transition-colors",
                        active
                          ? ANSWER_STYLE[opt.value]
                          : "border-hairline bg-[var(--surface)] text-foreground hover:bg-[var(--surface-2)]"
                      )}
                    >
                      <AppIcon name={ANSWER_ICON[opt.value]} size={16} />
                      {opt.label}
                    </button>
                  );
                })}
              </div>
              {sel?.answer === "blocked" && (
                <Input
                  className="mt-2"
                  placeholder="Что мешает? (необязательно)"
                  maxLength={REASON_MAX}
                  value={sel.reason ?? ""}
                  disabled={busy}
                  autoFocus={!item.answer}
                  onChange={(e) =>
                    setSelection((prev) => ({
                      ...prev,
                      [item.task_id]: { answer: "blocked", reason: e.target.value },
                    }))
                  }
                />
              )}
            </li>
          );
        })}
      </ul>
      {err && <p className="text-sm text-[var(--danger)]">{err}</p>}
      <div className="flex items-center gap-3">
        <span className="text-xs tabular-nums text-muted">
          {answered} из {checkin.items.length}
        </span>
        <Button className="ml-auto min-w-[8rem]" disabled={busy} onClick={() => void submit()}>
          {busy ? "Сохраняем…" : "Готово"}
        </Button>
      </div>
    </div>
  );
}

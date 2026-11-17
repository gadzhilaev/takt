"use client";

import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { AppIcon } from "@/components/ui/app-icon";
import { EmptyState } from "@/components/ui/empty-state";
import { ErrorState } from "@/components/ui/error-state";
import { Skeleton } from "@/components/ui/skeleton";
import { api } from "@/lib/api";
import {
  PERIODS,
  daysLabel,
  formatHours,
  missedLabel,
  participationLabel,
  periodLabel,
  type Digest,
  type DigestPeriod,
  type DigestTask,
} from "@/lib/digest";
import { formatDueChip } from "@/lib/format-due-date";
import { urgencyLabel } from "@/lib/urgency";
import { cn } from "@/lib/utils";

function Stat({ value, label, tone }: { value: string | number; label: string; tone?: string }) {
  return (
    <div className="rounded-[var(--radius)] border border-hairline bg-[var(--surface)] px-3 py-3">
      <div className={cn("text-2xl font-semibold tabular-nums", tone)}>{value}</div>
      <div className="mt-0.5 text-xs text-muted">{label}</div>
    </div>
  );
}

function Section({
  title,
  count,
  children,
}: {
  title: string;
  count?: number;
  children: React.ReactNode;
}) {
  return (
    <section className="rounded-[var(--radius)] border border-hairline bg-[var(--surface)]">
      <h2 className="flex items-center gap-2 border-b border-hairline px-3 py-2.5 text-sm font-semibold">
        {title}
        {count !== undefined && <span className="text-xs font-normal text-muted">{count}</span>}
      </h2>
      <div className="divide-y divide-[var(--border)]">{children}</div>
    </section>
  );
}

function TaskRow({
  projectId,
  task,
  meta,
  note,
}: {
  projectId: string;
  task: DigestTask;
  meta?: React.ReactNode;
  note?: React.ReactNode;
}) {
  return (
    <Link
      href={`/app/projects/${projectId}?view=digest&task=${task.task_id}`}
      className="block px-3 py-2.5 hover:bg-[var(--surface-2)]"
    >
      <div className="flex items-start gap-2">
        <span className="min-w-0 flex-1 text-sm font-medium text-foreground">{task.title}</span>
        <AppIcon name="chevron-right" size={16} className="mt-0.5 shrink-0 text-muted" />
      </div>
      <div className="mt-0.5 flex flex-wrap gap-x-2 text-xs text-muted">
        {meta}
        {task.assignees.length > 0 && <span>{task.assignees.join(", ")}</span>}
      </div>
      {note && <div className="mt-1 text-xs text-foreground/85">{note}</div>}
    </Link>
  );
}

function Empty({ text }: { text: string }) {
  return <p className="px-3 py-3 text-sm text-muted">{text}</p>;
}

export function DigestView({ projectId }: { projectId: string }) {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  const qc = useQueryClient();
  const period = (params.get("period") as DigestPeriod) || "week";
  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: ["digest", projectId, period],
    queryFn: () =>
      api<{ digest: Digest }>(`/api/v1/projects/${projectId}/digest?period=${period}`),
  });
  const d = data?.digest;
  const now = new Date();

  async function toggleSubscription(next: boolean) {
    await api(`/api/v1/projects/${projectId}/digest-subscription`, {
      method: "PUT",
      json: { subscribed: next },
    });
    qc.invalidateQueries({ queryKey: ["digest", projectId] });
  }

  return (
    <div className="mx-auto w-full max-w-3xl pb-8">
      <div className="flex flex-wrap items-center gap-3">
        {d && <span className="text-sm text-muted">{periodLabel(d.period)}</span>}
        <div
          className="ml-auto flex rounded-[var(--radius)] bg-[var(--surface-2)] p-0.5"
          role="tablist"
          aria-label="Период сводки"
        >
          {PERIODS.map((p) => (
            <button
              key={p.value}
              type="button"
              role="tab"
              aria-selected={period === p.value}
              onClick={() => {
                const next = new URLSearchParams(params.toString());
                next.set("view", "digest");
                next.set("period", p.value);
                router.replace(`${pathname}?${next.toString()}`, { scroll: false });
              }}
              className={cn(
                "min-h-8 rounded-[calc(var(--radius)-2px)] px-3 text-[13px] font-medium",
                period === p.value
                  ? "bg-[var(--surface)] text-[var(--accent)] shadow-sm"
                  : "text-muted hover:text-foreground"
              )}
            >
              {p.label}
            </button>
          ))}
        </div>
      </div>

      {isLoading && <Skeleton className="mt-4 h-64 w-full" />}
      {isError && <ErrorState className="mt-4" onRetry={() => void refetch()} />}

      {d && (
        <div className="mt-4 space-y-3">
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
            <Stat value={d.summary.done} label="сделано" tone="text-[var(--success)]" />
            <Stat
              value={d.summary.stuck}
              label="застряло"
              tone={d.summary.stuck ? "text-[var(--warning)]" : undefined}
            />
            <Stat
              value={d.summary.overdue}
              label="просрочено"
              tone={d.summary.overdue ? "text-[var(--danger)]" : undefined}
            />
            <Stat value={participationLabel(d.summary.participation)} label="ответы на чек-ин" />
          </div>

          <Section title="Застряло" count={d.stuck.length}>
            {d.stuck.length ? (
              d.stuck.map((t) => (
                <TaskRow
                  key={t.task_id}
                  projectId={projectId}
                  task={t}
                  meta={<span>{daysLabel(t.days_stuck ?? 0)}</span>}
                  note={
                    <span className="border-l-2 border-[var(--warning)] pl-1.5">
                      {t.reason || "Причина не указана"}
                      {t.blocked_by ? ` · ${t.blocked_by}` : ""}
                    </span>
                  }
                />
              ))
            ) : (
              <Empty text="Ничего не застряло." />
            )}
          </Section>

          <Section title="Просрочено и скоро срок" count={d.overdue.length + d.due_soon.length}>
            {d.overdue.length + d.due_soon.length ? (
              <>
                {d.overdue.map((t) => (
                  <TaskRow
                    key={t.task_id}
                    projectId={projectId}
                    task={t}
                    meta={
                      <span className="text-[var(--danger)]">
                        просрочено {formatDueChip(t.due_date, now)}
                      </span>
                    }
                  />
                ))}
                {d.due_soon.map((t) => (
                  <TaskRow
                    key={t.task_id}
                    projectId={projectId}
                    task={t}
                    meta={<span>до срока {formatDueChip(t.due_date, now)}</span>}
                  />
                ))}
              </>
            ) : (
              <Empty text="Просрочек нет, ближайшие 48 часов спокойные." />
            )}
          </Section>

          <Section title="Узкое место">
            {d.bottleneck ? (
              <>
                <p className="px-3 py-2.5 text-sm">
                  Дольше всего задачи стоят в «{d.bottleneck.name}» — в среднем{" "}
                  <span className="font-semibold">{formatHours(d.bottleneck.avg_hours)}</span>
                </p>
                {d.bottleneck.tasks.map((t) => (
                  <TaskRow
                    key={t.task_id}
                    projectId={projectId}
                    task={t}
                    meta={<span>в столбце {formatHours(t.hours_in_status ?? 0)}</span>}
                  />
                ))}
              </>
            ) : (
              <Empty text="За этот период данных о переносах нет." />
            )}
          </Section>

          <Section title="Сделано" count={d.done.length}>
            {d.done.length ? (
              d.done.map((t) => (
                <TaskRow
                  key={t.task_id}
                  projectId={projectId}
                  task={t}
                  meta={<span>{urgencyLabel(t.priority)}</span>}
                />
              ))
            ) : (
              <Empty text="За этот период ничего не закрыто." />
            )}
          </Section>

          <Section title="Ритм">
            {d.rhythm.total ? (
              <>
                <p className="px-3 py-2.5 text-sm">
                  Ответы на чек-ин: {d.rhythm.answered} из {d.rhythm.total} (
                  {participationLabel(d.rhythm.participation)})
                </p>
                {d.rhythm.members_without_answer?.map((m) => (
                  <p key={m.user_id} className="px-3 py-2 text-sm">
                    {m.name} <span className="text-muted">— {missedLabel(m)}</span>
                  </p>
                ))}
              </>
            ) : (
              <Empty
                text={
                  d.rhythm.enabled
                    ? "Чек-инов за этот период ещё не было."
                    : "Ежедневный чек-ин выключен — включите его в настройках проекта."
                }
              />
            )}
          </Section>

          <label className="flex cursor-pointer items-center gap-2.5 rounded-[var(--radius)] border border-hairline bg-[var(--surface)] px-3 py-2.5 text-sm">
            <input
              type="checkbox"
              className="h-4 w-4 accent-[var(--accent)]"
              checked={d.viewer.subscribed}
              onChange={(e) => void toggleSubscription(e.target.checked)}
            />
            Получать сводку в уведомлениях
        </label>
          {!d.done.length && !d.stuck.length && !d.overdue.length && !d.rhythm.total && (
            <EmptyState
              title="Пока тихо"
              description="Сводка наполнится, когда команда начнёт закрывать задачи и отвечать на чек-ин."
            />
          )}
        </div>
      )}
    </div>
  );
}

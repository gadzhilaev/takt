"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { isPast, isToday, isTomorrow, parseISO } from "date-fns";
import { api } from "@/lib/api";
import type { Task } from "@/lib/types";
import { priorityLabel } from "@/lib/utils";
import { ErrorState } from "@/components/ui/error-state";
import { EmptyState } from "@/components/ui/empty-state";
import { Skeleton } from "@/components/ui/skeleton";

function due(d: string) {
  return parseISO(d.endsWith("Z") ? d : `${d}Z`);
}

function Group({ title, items }: { title: string; items: Task[] }) {
  if (!items.length) return null;
  return (
    <section className="space-y-2">
      <h2 className="text-sm font-semibold uppercase tracking-wide text-muted">{title}</h2>
      <ul className="space-y-2">
        {items.map((t) => (
          <li key={t.id}>
            <Link
              href={`/tasks/${t.id}`}
              className="surface-panel flex min-h-[52px] flex-col justify-center p-3 hover:border-[var(--border-strong)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-[var(--ring)]"
            >
              <span className="font-medium text-foreground">{t.title}</span>
              <span className="text-xs text-muted">
                {t.status?.name} · {priorityLabel(t.priority)}
              </span>
            </Link>
          </li>
        ))}
      </ul>
    </section>
  );
}

export default function MyTasksPage() {
  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ["tasks", "mine"],
    queryFn: () => api<{ items: Task[] }>("/api/v1/tasks?mine=true&page_size=500"),
  });

  if (isLoading) return <Skeleton className="h-48 w-full" />;
  if (isError) return <ErrorState message={(error as Error).message} onRetry={() => refetch()} />;

  const tasks = data?.items ?? [];
  const overdue = tasks.filter((t) => t.due_date && !t.closed_at && isPast(due(t.due_date)) && !isToday(due(t.due_date)));
  const today = tasks.filter((t) => t.due_date && !t.closed_at && isToday(due(t.due_date)));
  const tomorrow = tasks.filter((t) => t.due_date && !t.closed_at && isTomorrow(due(t.due_date)));
  const upcoming = tasks.filter(
    (t) =>
      t.due_date &&
      !t.closed_at &&
      !isPast(due(t.due_date)) &&
      !isToday(due(t.due_date)) &&
      !isTomorrow(due(t.due_date))
  );
  const noDate = tasks.filter((t) => !t.due_date && !t.closed_at);
  const done = tasks.filter((t) => !!t.closed_at);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="page-title">Мои задачи</h1>
        <p className="page-subtitle">Здесь всё, что назначено вам или создано вами — по срокам</p>
      </div>
      {!tasks.length ? (
        <EmptyState
          title="Пока нет ваших задач"
          description="Нажмите «Создать задачу» внизу экрана или откройте проект"
        />
      ) : (
        <>
          <Group title="Просрочено" items={overdue} />
          <Group title="Сегодня" items={today} />
          <Group title="Завтра" items={tomorrow} />
          <Group title="Позже" items={upcoming} />
          <Group title="Без срока" items={noDate} />
          <Group title="Завершено" items={done} />
        </>
      )}
    </div>
  );
}

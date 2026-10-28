"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { format, isPast, isToday, parseISO, startOfDay } from "date-fns";
import { ru } from "date-fns/locale";
import { Plus, ArrowRight, AlertTriangle, CalendarDays, ClipboardCheck } from "lucide-react";
import { api } from "@/lib/api";
import type { Project, Task } from "@/lib/types";
import { ErrorState } from "@/components/ui/error-state";
import { Skeleton } from "@/components/ui/skeleton";
import { Button } from "@/components/ui/button";
import { priorityLabel, cn } from "@/lib/utils";

function parseDue(d: string) {
  return parseISO(d.endsWith("Z") ? d : `${d}Z`);
}

function TaskRow({ task }: { task: Task }) {
  return (
    <Link
      href={`/tasks/${task.id}`}
      className="flex min-h-[44px] items-start justify-between gap-2 rounded-lg px-2 py-1.5 hover:bg-[var(--surface-2)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-[var(--ring)]"
    >
      <span className="min-w-0">
        <span className="block truncate text-sm font-medium">{task.title}</span>
        <span className="text-xs text-muted">
          {task.status?.name || "Без статуса"}
          {task.due_date ? ` · ${format(parseDue(task.due_date), "d MMM", { locale: ru })}` : ""}
          {` · ${priorityLabel(task.priority)}`}
        </span>
      </span>
      <ArrowRight className="mt-1 h-4 w-4 shrink-0 text-muted" aria-hidden />
    </Link>
  );
}

export default function HomePage() {
  const tasksQuery = useQuery({
    queryKey: ["tasks", "home"],
    queryFn: () => api<{ items: Task[] }>("/api/v1/tasks?mine=true&page_size=500"),
    staleTime: 15_000,
  });
  const projectsQuery = useQuery({
    queryKey: ["projects"],
    queryFn: () => api<{ items: Project[] }>("/api/v1/projects"),
    staleTime: 30_000,
  });

  if (tasksQuery.isLoading || projectsQuery.isLoading) {
    return (
      <div className="grid gap-3 md:grid-cols-3">
        <Skeleton className="h-24" />
        <Skeleton className="h-24" />
        <Skeleton className="h-24" />
      </div>
    );
  }
  if (tasksQuery.isError) {
    return <ErrorState message={(tasksQuery.error as Error).message} onRetry={() => tasksQuery.refetch()} />;
  }

  const tasks = tasksQuery.data?.items ?? [];
  const projects = projectsQuery.data?.items ?? [];
  const defaultProject = projects.find((p) => p.is_default) ?? projects[0];
  const today = startOfDay(new Date());
  const overdue = tasks.filter(
    (t) => t.due_date && !t.closed_at && isPast(parseDue(t.due_date)) && !isToday(parseDue(t.due_date))
  );
  const dueToday = tasks.filter((t) => t.due_date && !t.closed_at && isToday(parseDue(t.due_date)));
  const review = tasks.filter((t) => t.status?.name.toLowerCase().includes("провер") && !t.closed_at);
  const openCount = tasks.filter((t) => !t.closed_at && !t.status?.is_done).length;

  const summary = [
    {
      id: "overdue",
      title: "Просрочено",
      short: "Просроч.",
      count: overdue.length,
      href: "#section-overdue",
      icon: AlertTriangle,
      tone: "danger" as const,
    },
    {
      id: "today",
      title: "На сегодня",
      short: "Сегодня",
      count: dueToday.length,
      href: "#section-today",
      icon: CalendarDays,
      tone: "default" as const,
    },
    {
      id: "review",
      title: "Ждут проверки",
      short: "Проверка",
      count: review.length,
      href: "#section-review",
      icon: ClipboardCheck,
      tone: "default" as const,
    },
  ];

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="page-title">Обзор</h1>
          <p className="page-subtitle">
            {format(today, "d MMMM yyyy", { locale: ru })} · открытых задач: {openCount}
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button asChild variant="secondary">
            <Link href="/my">Мои задачи</Link>
          </Button>
          {defaultProject && (
            <Button asChild>
              <Link href={`/projects/${defaultProject.id}?create=1`}>
                <Plus className="h-4 w-4" /> Создать задачу
              </Link>
            </Button>
          )}
        </div>
      </div>

      <div className="grid grid-cols-3 gap-1.5 sm:gap-2">
        {summary.map(({ id, title, short, count, href, icon: Icon, tone }) => (
          <a
            key={id}
            href={href}
            className={cn(
              "stat-tile transition hover:border-[var(--border-strong)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-[var(--ring)]",
              "min-h-[48px] items-center gap-2 px-2 py-1.5 sm:min-h-[3.25rem] sm:gap-2.5 sm:px-3",
              tone === "danger" && count > 0 && "border-[color-mix(in_srgb,var(--danger)_35%,var(--border))]"
            )}
          >
            <Icon
              className={cn(
                "h-3.5 w-3.5 shrink-0 sm:h-4 sm:w-4",
                tone === "danger" && count > 0 ? "text-[var(--danger)]" : "text-[var(--accent)]"
              )}
              aria-hidden
            />
            <div className="min-w-0 flex-1">
              <div className="text-[11px] font-semibold leading-tight sm:hidden">{short}</div>
              <div className="hidden text-[13px] font-semibold sm:block">{title}</div>
              <div className="hidden text-[11px] text-muted sm:block">К списку</div>
            </div>
            <div
              className={cn(
                "text-base font-semibold tabular-nums sm:text-xl",
                tone === "danger" && count > 0 ? "text-[var(--danger)]" : "text-foreground"
              )}
            >
              {count}
            </div>
          </a>
        ))}
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <section id="section-overdue" className="surface-panel p-3 scroll-mt-24">
          <div className="mb-2 flex items-center justify-between px-1">
            <h2 className="text-sm font-semibold">Просроченные</h2>
            <Link href="/my" className="text-xs font-semibold text-[var(--accent)]">
              Все мои
            </Link>
          </div>
          {overdue.length ? (
            <ul className="divide-y divide-[var(--border)]">
              {overdue.slice(0, 5).map((t) => (
                <li key={t.id}>
                  <TaskRow task={t} />
                </li>
              ))}
            </ul>
          ) : (
            <p className="px-2 py-3 text-sm text-muted">Нет просроченных — отлично</p>
          )}
        </section>

        <section id="section-today" className="surface-panel p-3 scroll-mt-24">
          <h2 className="mb-2 px-1 text-sm font-semibold">На сегодня</h2>
          {dueToday.length ? (
            <ul className="divide-y divide-[var(--border)]">
              {dueToday.slice(0, 5).map((t) => (
                <li key={t.id}>
                  <TaskRow task={t} />
                </li>
              ))}
            </ul>
          ) : (
            <p className="px-2 py-3 text-sm text-muted">На сегодня ничего не запланировано</p>
          )}
        </section>

        <section id="section-review" className="surface-panel p-3 scroll-mt-24 lg:col-span-2">
          <h2 className="mb-2 px-1 text-sm font-semibold">Ждут проверки · {review.length}</h2>
          {review.length ? (
            <ul className="grid gap-0 sm:grid-cols-2 divide-y sm:divide-y-0 sm:gap-x-4">
              {review.slice(0, 6).map((t) => (
                <li key={t.id} className="border-b border-hairline sm:border-0">
                  <TaskRow task={t} />
                </li>
              ))}
            </ul>
          ) : (
            <p className="px-2 py-3 text-sm text-muted">Нет задач на проверке</p>
          )}
        </section>
      </div>

      <section className="surface-panel p-3 md:p-4">
        <div className="mb-2 flex items-center justify-between">
          <h2 className="text-sm font-semibold">Проекты</h2>
          <Link href="/projects" className="text-xs font-semibold text-[var(--accent)]">
            Все проекты
          </Link>
        </div>
        <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
          {projects.map((p) => (
            <Link
              key={p.id}
              href={`/projects/${p.id}`}
              className="rounded-[var(--radius-lg)] border border-hairline bg-[var(--surface-2)] px-3 py-2.5 transition hover:border-[var(--accent)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-[var(--ring)]"
            >
              <div className="mb-1.5 flex items-center gap-2">
                <span className="h-2.5 w-2.5 rounded-full" style={{ background: p.color }} />
                <span className="truncate text-sm font-semibold">{p.name}</span>
              </div>
              <div className="mb-1 h-1.5 overflow-hidden rounded-full bg-[var(--border)]">
                <div
                  className="h-full rounded-full bg-[var(--accent)]"
                  style={{ width: `${p.progress?.percent ?? 0}%` }}
                />
              </div>
              <div className="text-xs text-muted">
                {p.progress?.done ?? 0}/{p.progress?.total ?? 0}
              </div>
            </Link>
          ))}
        </div>
      </section>
    </div>
  );
}

"use client";

import { Suspense, useCallback, useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { format, parseISO } from "date-fns";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { api } from "@/lib/api";
import type { Task } from "@/lib/types";
import { priorityLabel } from "@/lib/utils";
import { ErrorState } from "@/components/ui/error-state";
import { EmptyState } from "@/components/ui/empty-state";
import { Skeleton } from "@/components/ui/skeleton";
import { Button } from "@/components/ui/button";

type SortKey = "updated" | "due" | "priority" | "title";

function ListPageInner() {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const search = searchParams.get("search") ?? searchParams.get("q") ?? "";
  const sort = (searchParams.get("sort") as SortKey) || "updated";
  const [selected, setSelected] = useState<string[]>([]);

  const setParam = useCallback(
    (key: string, value: string) => {
      const next = new URLSearchParams(searchParams.toString());
      if (key === "q") next.delete("search");
      if (value) next.set(key, value);
      else next.delete(key);
      const qs = next.toString();
      router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
    },
    [pathname, router, searchParams]
  );

  const { data, isLoading, isError, error, refetch, isFetching } = useQuery({
    queryKey: ["tasks", "list", search],
    queryFn: () =>
      api<{ items: Task[] }>(
        `/api/v1/tasks?page_size=1000${search ? `&search=${encodeURIComponent(search)}` : ""}`
      ),
  });

  const tasks = useMemo(() => {
    const items = [...(data?.items ?? [])];
    const pri = { urgent: 0, high: 1, medium: 2, low: 3 } as const;
    items.sort((a, b) => {
      if (sort === "title") return a.title.localeCompare(b.title, "ru");
      if (sort === "priority") return pri[a.priority] - pri[b.priority];
      if (sort === "due") return (a.due_date || "9999").localeCompare(b.due_date || "9999");
      return b.updated_at.localeCompare(a.updated_at);
    });
    return items;
  }, [data, sort]);

  async function bulkArchive() {
    for (const id of selected) {
      await api(`/api/v1/tasks/${id}`, { method: "PATCH", json: { archived: true } });
    }
    setSelected([]);
    refetch();
  }

  if (isLoading) return <Skeleton className="h-64 w-full" />;
  if (isError) return <ErrorState message={(error as Error).message} onRetry={() => refetch()} />;

  return (
    <div>
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="page-title">Список задач</h1>
          <p className="page-subtitle">
            Все задачи в одной таблице — удобно искать и сортировать
            {isFetching && !isLoading ? " · обновление…" : ""}
          </p>
        </div>
        <div className="flex w-full flex-wrap gap-2 sm:w-auto">
          <input
            className="field min-w-0 flex-1 sm:w-44 sm:flex-none"
            placeholder="Поиск"
            aria-label="Поиск в списке"
            value={search}
            onChange={(e) => setParam("search", e.target.value)}
          />
          <select
            className="field w-auto"
            value={sort}
            aria-label="Сортировка"
            onChange={(e) => setParam("sort", e.target.value)}
          >
            <option value="updated">По обновлению</option>
            <option value="due">По сроку</option>
            <option value="priority">По приоритету</option>
            <option value="title">По названию</option>
          </select>
          {selected.length > 0 && (
            <Button size="sm" variant="secondary" onClick={bulkArchive}>
              В архив ({selected.length})
            </Button>
          )}
        </div>
      </div>
      {!tasks.length ? (
        <EmptyState title="Задач нет" description="Создайте задачу на доске проекта или измените поиск" />
      ) : (
        <div className="surface-panel overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead className="bg-[var(--surface-2)]">
              <tr>
                <th className="px-3 py-3 text-left" />
                {["Название", "Статус", "Важность", "Срок", "Исполнители"].map((h) => (
                  <th key={h} className="px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-muted">
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {tasks.map((t) => (
                <tr key={t.id} className="border-t border-hairline hover:bg-[var(--surface-2)]">
                  <td className="px-3 py-2">
                    <input
                      type="checkbox"
                      className="h-5 w-5 accent-[var(--accent)]"
                      checked={selected.includes(t.id)}
                      aria-label={`Выбрать «${t.title}»`}
                      onChange={(e) =>
                        setSelected((prev) =>
                          e.target.checked ? [...prev, t.id] : prev.filter((x) => x !== t.id)
                        )
                      }
                    />
                  </td>
                  <td className="px-3 py-2">
                    <Link href={`/tasks/${t.id}`} className="font-medium text-[var(--accent)] hover:underline">
                      {t.title}
                    </Link>
                  </td>
                  <td className="px-3 py-2">{t.status?.name}</td>
                  <td className="px-3 py-2">{priorityLabel(t.priority)}</td>
                  <td className="px-3 py-2">
                    {t.due_date ? format(parseISO(t.due_date), "dd.MM.yyyy") : "—"}
                  </td>
                  <td className="px-3 py-2">{t.assignees.map((a) => a.name).join(", ") || "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

export default function ListPage() {
  return (
    <Suspense fallback={<Skeleton className="h-64 w-full" />}>
      <ListPageInner />
    </Suspense>
  );
}

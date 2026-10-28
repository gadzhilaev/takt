"use client";

import { useQuery } from "@tanstack/react-query";
import { format, parseISO } from "date-fns";
import { api } from "@/lib/api";
import type { Task } from "@/lib/types";
import { priorityLabel } from "@/lib/utils";

export default function ListPage() {
  const { data, isLoading } = useQuery({
    queryKey: ["tasks"],
    queryFn: () => api<{ items: Task[] }>("/api/v1/tasks?page_size=1000"),
  });
  const tasks = data?.items ?? [];

  return (
    <div>
      <h1 className="mb-4 text-2xl font-semibold">Список</h1>
      {isLoading ? (
        <p className="text-slate-500">Загрузка…</p>
      ) : (
        <div className="overflow-x-auto rounded-xl border dark:border-slate-800">
          <table className="min-w-full text-sm">
            <thead className="bg-slate-100 dark:bg-slate-900">
              <tr>
                {["Название", "Статус", "Приоритет", "Срок", "Исполнители"].map((h) => (
                  <th key={h} className="px-3 py-2 text-left font-medium">
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {tasks.map((t) => (
                <tr key={t.id} className="border-t dark:border-slate-800">
                  <td className="px-3 py-2">{t.title}</td>
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

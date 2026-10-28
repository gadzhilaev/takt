"use client";

import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { Task } from "@/lib/types";
import { priorityLabel } from "@/lib/utils";

export default function MyTasksPage() {
  const { data } = useQuery({
    queryKey: ["tasks", "mine"],
    queryFn: () => api<{ items: Task[] }>("/api/v1/tasks?mine=true&page_size=500"),
  });
  const tasks = data?.items ?? [];

  return (
    <div>
      <h1 className="mb-2 text-2xl font-semibold">Мои задачи</h1>
      <p className="mb-4 text-sm text-slate-500">Где вы автор или исполнитель</p>
      <ul className="space-y-2">
        {tasks.map((t) => (
          <li key={t.id} className="rounded-lg border p-3 dark:border-slate-800">
            <div className="font-medium">{t.title}</div>
            <div className="text-xs text-slate-500">
              {t.status?.name} · {priorityLabel(t.priority)}
            </div>
          </li>
        ))}
        {!tasks.length && <p className="text-slate-500">Пока нет задач — создайте на доске (клавиша C)</p>}
      </ul>
    </div>
  );
}

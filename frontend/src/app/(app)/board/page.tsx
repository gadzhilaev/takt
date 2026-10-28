"use client";

import { KanbanBoard } from "@/components/kanban-board";
import { Button } from "@/components/ui/button";
export default function BoardPage() {
  async function exportTasks() {
    const res = await fetch("/api/v1/reports/export", { credentials: "include" });
    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "export.xlsx";
    a.click();
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h1 className="text-2xl font-semibold">Доска</h1>
          <p className="text-sm text-slate-500">Перетаскивайте карточки или меняйте статус в задаче</p>
        </div>
        <Button variant="secondary" onClick={exportTasks}>
          Экспорт задач
        </Button>
      </div>
      <KanbanBoard />
    </div>
  );
}

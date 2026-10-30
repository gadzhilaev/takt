import { cn } from "@/lib/utils";
import { columnShellStyle } from "@/lib/column-colors";

type DemoTask = {
  title: string;
  urgency?: "Средняя" | "Высокая" | "Срочно";
  assignees: string[];
  done?: boolean;
};

type DemoColumn = {
  name: string;
  /** Stored status.color — same presets as real board */
  accent: string;
  tasks: DemoTask[];
};

const COLUMNS: DemoColumn[] = [
  {
    name: "К выполнению",
    accent: "#607FA4",
    tasks: [
      { title: "Собрать бриф по запуску", urgency: "Средняя", assignees: ["АК"] },
      { title: "Согласовать доступы команде", assignees: ["МИ", "ЕК"] },
    ],
  },
  {
    name: "В работе",
    accent: "#347FA4",
    tasks: [
      { title: "Настроить доску проекта", urgency: "Высокая", assignees: ["АК"] },
      { title: "Описать статусы и правила", assignees: ["ЕК"] },
    ],
  },
  {
    name: "На проверке",
    accent: "#9062B8",
    tasks: [{ title: "Проверить приглашения", urgency: "Средняя", assignees: ["МИ"] }],
  },
  {
    name: "Готово",
    accent: "#398A62",
    tasks: [{ title: "Создать рабочий проект", assignees: ["АК"], done: true }],
  },
];

function UrgencyDot({ label }: { label: NonNullable<DemoTask["urgency"]> }) {
  const color =
    label === "Срочно" ? "var(--priority-urgent)" : label === "Высокая" ? "var(--priority-high)" : "var(--priority-medium)";
  return (
    <span className="inline-flex items-center gap-1 text-[11px] text-[var(--kanban-card-desc)]">
      <span className="h-1.5 w-1.5 rounded-full" style={{ background: color }} aria-hidden />
      {label}
    </span>
  );
}

/** Static, anonymized Kanban mock — column colors follow real board light/dark presets. */
export function LandingKanbanDemo({ className }: { className?: string }) {
  return (
    <div
      className={cn(
        "overflow-hidden rounded-[var(--radius-lg)] border border-[var(--border)] bg-[var(--kanban-board-bg)] shadow-[0_12px_40px_rgba(32,41,56,0.08)] dark:shadow-[0_12px_40px_rgba(0,0,0,0.35)]",
        className
      )}
      role="img"
      aria-label="Пример доски Takt: четыре столбца с задачами"
    >
      <div className="flex items-center justify-between border-b border-[var(--border)] bg-[var(--surface)] px-4 py-3">
        <div>
          <p className="text-[13px] font-semibold text-[var(--foreground)]">Команда продукта</p>
          <p className="text-[12px] text-muted">Демонстрационная доска</p>
        </div>
        <span className="rounded-full bg-[var(--accent-soft)] px-2.5 py-1 text-[11px] font-medium text-[var(--accent)]">
          Пример
        </span>
      </div>
      <div className="flex gap-3 overflow-x-auto p-3 sm:p-4">
        {COLUMNS.map((col) => (
          <section
            key={col.name}
            className="kanban-column-shell w-[min(72vw,15.5rem)] shrink-0 rounded-[var(--radius)] border p-2.5"
            style={columnShellStyle(col.accent)}
          >
            <header className="mb-2.5 flex items-center gap-2 px-1">
              <span
                className="h-2 w-2 shrink-0 rounded-full"
                style={{ background: "var(--kanban-col-accent)" }}
                aria-hidden
              />
              <h3 className="text-[12px] font-semibold tracking-tight text-[var(--foreground)]">{col.name}</h3>
              <span className="ml-auto text-[11px] tabular-nums text-muted">{col.tasks.length}</span>
            </header>
            <ul className="space-y-2">
              {col.tasks.map((task) => (
                <li
                  key={task.title}
                  className="rounded-[var(--radius-sm)] border border-[var(--kanban-card-border)] bg-[var(--kanban-card-bg)] p-2.5 shadow-[var(--kanban-card-shadow)]"
                >
                  <p
                    className={cn(
                      "text-[13px] font-medium leading-snug",
                      task.done ? "text-[var(--kanban-done-title)] line-through" : "text-[var(--kanban-card-title)]"
                    )}
                  >
                    {task.title}
                  </p>
                  <div className="mt-2 flex items-center justify-between gap-2">
                    {task.urgency ? <UrgencyDot label={task.urgency} /> : <span />}
                    <div className="flex -space-x-1.5">
                      {task.assignees.map((a) => (
                        <span
                          key={a}
                          className="flex h-6 w-6 items-center justify-center rounded-full border border-[var(--surface)] bg-[var(--accent-soft)] text-[9px] font-semibold text-[var(--accent)]"
                        >
                          {a}
                        </span>
                      ))}
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          </section>
        ))}
      </div>
    </div>
  );
}

"use client";

import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
  type ReactNode,
} from "react";
import { cn } from "@/lib/utils";
import { type SortDir } from "@/components/admin/sortable-th";

export type DataTableColumn<T> = {
  id: string;
  label: string;
  width?: number;
  minWidth?: number;
  sortable?: boolean;
  sortKey?: string;
  className?: string;
  cell: (row: T) => ReactNode;
};

type Props<T> = {
  storageKey: string;
  columns: DataTableColumn<T>[];
  rows: T[];
  rowKey: (row: T) => string;
  sort?: string;
  dir?: SortDir;
  onSort?: (column: string) => void;
  isFetching?: boolean;
  empty?: ReactNode;
  onRowClick?: (row: T) => void;
};

type Persist = { widths: Record<string, number> };

function loadPersist(key: string): Persist | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = localStorage.getItem(key);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Persist & { order?: string[] };
    return { widths: parsed.widths ?? {} };
  } catch {
    return null;
  }
}

function savePersist(key: string, value: Persist) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    /* ignore */
  }
}

export function DataTable<T>({
  storageKey,
  columns,
  rows,
  rowKey,
  sort,
  dir,
  onSort,
  isFetching,
  empty,
  onRowClick,
}: Props<T>) {
  const defaultWidths = useMemo(() => {
    const widths: Record<string, number> = {};
    for (const c of columns) widths[c.id] = c.width ?? 140;
    return widths;
  }, [columns]);

  const [widths, setWidths] = useState<Record<string, number>>(defaultWidths);
  const resize = useRef<{ id: string; startX: number; startW: number } | null>(null);

  useEffect(() => {
    const saved = loadPersist(storageKey);
    if (!saved?.widths) return;
    setWidths({ ...defaultWidths, ...saved.widths });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [storageKey]);

  useEffect(() => {
    savePersist(storageKey, { widths });
  }, [storageKey, widths]);

  const byId = useMemo(() => new Map(columns.map((c) => [c.id, c])), [columns]);

  const onResizeMove = useCallback(
    (e: MouseEvent) => {
      const r = resize.current;
      if (!r) return;
      const col = byId.get(r.id);
      const min = col?.minWidth ?? 80;
      const next = Math.max(min, r.startW + (e.clientX - r.startX));
      setWidths((prev) => ({ ...prev, [r.id]: next }));
    },
    [byId]
  );

  const onResizeUp = useCallback(() => {
    resize.current = null;
    window.removeEventListener("mousemove", onResizeMove);
    window.removeEventListener("mouseup", onResizeUp);
  }, [onResizeMove]);

  const startResize = (id: string, e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    resize.current = { id, startX: e.clientX, startW: widths[id] ?? 140 };
    window.addEventListener("mousemove", onResizeMove);
    window.addEventListener("mouseup", onResizeUp);
  };

  if (!rows.length && !isFetching) {
    return (
      <div className="rounded-[var(--radius)] border border-[var(--border)] bg-white px-4 py-8 text-center text-[13px] text-muted">
        {empty ?? "Нет данных"}
      </div>
    );
  }

  const minWidth = columns.reduce((s, c) => s + (widths[c.id] ?? 140), 0);

  return (
    <div className="relative overflow-x-auto rounded-[var(--radius)] border border-[var(--border)] bg-white">
      {isFetching ? (
        <div className="pointer-events-none absolute inset-x-0 top-0 z-10 h-0.5 overflow-hidden bg-[#eef1f4]">
          <div className="h-full w-1/3 animate-pulse bg-[var(--accent)]" />
        </div>
      ) : null}
      <table
        className="w-full border-collapse text-left text-[13px]"
        style={{ tableLayout: "fixed", minWidth }}
      >
        <colgroup>
          {columns.map((c) => (
            <col key={c.id} style={{ width: widths[c.id] ?? 140 }} />
          ))}
        </colgroup>
        <thead>
          <tr className="bg-[#f4f6f8]">
            {columns.map((c) => {
              const sortKey = c.sortKey ?? c.id;
              const active = Boolean(c.sortable && sort === sortKey);
              return (
                <th
                  key={c.id}
                  className={cn(
                    "relative border border-[var(--border)] px-3 py-2 font-medium text-muted",
                    c.className
                  )}
                  style={{ width: widths[c.id] } as CSSProperties}
                >
                  {c.sortable && onSort ? (
                    <button
                      type="button"
                      className={cn(
                        "inline-flex max-w-full items-center gap-1 truncate text-left hover:text-foreground",
                        active ? "text-foreground" : "text-muted"
                      )}
                      onClick={() => onSort(sortKey)}
                    >
                      <span className="truncate">{c.label}</span>
                      <span className="shrink-0 text-[11px]" aria-hidden>
                        {active ? (dir === "asc" ? "↑" : "↓") : "↕"}
                      </span>
                    </button>
                  ) : (
                    <span className="truncate">{c.label}</span>
                  )}
                  <span
                    role="separator"
                    aria-orientation="vertical"
                    aria-label={`Ширина: ${c.label}`}
                    className="absolute inset-y-0 right-0 z-10 w-1.5 cursor-col-resize hover:bg-[var(--accent)]/35"
                    onMouseDown={(e) => startResize(c.id, e)}
                  />
                </th>
              );
            })}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, idx) => (
            <tr
              key={rowKey(row)}
              className={cn(
                idx % 2 === 1 ? "bg-[#fafbfc]" : "bg-white",
                onRowClick ? "cursor-pointer hover:bg-[#eef3f6]" : null
              )}
              onClick={onRowClick ? () => onRowClick(row) : undefined}
            >
              {columns.map((c) => (
                <td
                  key={c.id}
                  className={cn(
                    "truncate border border-[var(--border)] px-3 py-2 align-middle",
                    c.className
                  )}
                  style={{ width: widths[c.id] }}
                >
                  {c.cell(row)}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

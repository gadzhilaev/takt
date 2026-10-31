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

type Persist = { order: string[]; widths: Record<string, number> };

function loadPersist(key: string): Persist | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = localStorage.getItem(key);
    if (!raw) return null;
    return JSON.parse(raw) as Persist;
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
  const defaults = useMemo(() => {
    const widths: Record<string, number> = {};
    for (const c of columns) widths[c.id] = c.width ?? 140;
    return { order: columns.map((c) => c.id), widths };
  }, [columns]);

  const [order, setOrder] = useState<string[]>(defaults.order);
  const [widths, setWidths] = useState<Record<string, number>>(defaults.widths);
  const dragCol = useRef<string | null>(null);
  const resize = useRef<{ id: string; startX: number; startW: number } | null>(null);

  useEffect(() => {
    const saved = loadPersist(storageKey);
    if (!saved) return;
    const known = new Set(columns.map((c) => c.id));
    const nextOrder = [
      ...saved.order.filter((id) => known.has(id)),
      ...columns.map((c) => c.id).filter((id) => !saved.order.includes(id)),
    ];
    const nextWidths = { ...defaults.widths, ...saved.widths };
    setOrder(nextOrder);
    setWidths(nextWidths);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [storageKey]);

  useEffect(() => {
    savePersist(storageKey, { order, widths });
  }, [storageKey, order, widths]);

  const byId = useMemo(() => new Map(columns.map((c) => [c.id, c])), [columns]);
  const visible = order.map((id) => byId.get(id)).filter(Boolean) as DataTableColumn<T>[];

  const onResizeMove = useCallback((e: MouseEvent) => {
    const r = resize.current;
    if (!r) return;
    const col = byId.get(r.id);
    const min = col?.minWidth ?? 80;
    const next = Math.max(min, r.startW + (e.clientX - r.startX));
    setWidths((prev) => ({ ...prev, [r.id]: next }));
  }, [byId]);

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

  const onDragStart = (id: string) => {
    dragCol.current = id;
  };

  const onDragOver = (e: React.DragEvent, overId: string) => {
    e.preventDefault();
    const from = dragCol.current;
    if (!from || from === overId) return;
    setOrder((prev) => {
      const next = [...prev];
      const fromIdx = next.indexOf(from);
      const toIdx = next.indexOf(overId);
      if (fromIdx < 0 || toIdx < 0) return prev;
      next.splice(fromIdx, 1);
      next.splice(toIdx, 0, from);
      return next;
    });
    dragCol.current = overId;
  };

  const onDragEnd = () => {
    dragCol.current = null;
  };

  if (!rows.length && !isFetching) {
    return (
      <div className="rounded-[var(--radius)] border border-[var(--border)] bg-white px-4 py-8 text-center text-[13px] text-muted">
        {empty ?? "Нет данных"}
      </div>
    );
  }

  return (
    <div className="relative overflow-x-auto rounded-[var(--radius)] border border-[var(--border)] bg-white">
      {isFetching ? (
        <div className="pointer-events-none absolute inset-x-0 top-0 z-10 h-0.5 overflow-hidden bg-[#eef1f4]">
          <div className="h-full w-1/3 animate-pulse bg-[var(--accent)]" />
        </div>
      ) : null}
      <table className="w-full border-separate border-spacing-0 text-left text-[13px]" style={{ tableLayout: "fixed", minWidth: visible.reduce((s, c) => s + (widths[c.id] ?? 140), 0) }}>
        <colgroup>
          {visible.map((c) => (
            <col key={c.id} style={{ width: widths[c.id] ?? 140 }} />
          ))}
        </colgroup>
        <thead className="border-b border-[var(--border)] text-muted">
          <tr>
            {visible.map((c) => {
              const sortKey = c.sortKey ?? c.id;
              const active = Boolean(c.sortable && sort === sortKey);
              return (
                <th
                  key={c.id}
                  draggable
                  onDragStart={() => onDragStart(c.id)}
                  onDragOver={(e) => onDragOver(e, c.id)}
                  onDragEnd={onDragEnd}
                  className={cn(
                    "relative select-none border-b border-[var(--border)] bg-white px-3 py-2 font-medium",
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
                    className="absolute inset-y-0 right-0 w-1.5 cursor-col-resize hover:bg-[var(--accent)]/30"
                    onMouseDown={(e) => startResize(c.id, e)}
                  />
                </th>
              );
            })}
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr
              key={rowKey(row)}
              className={cn(
                "border-b border-[var(--border)] last:border-0",
                onRowClick ? "cursor-pointer hover:bg-[#f7f8fa]" : null
              )}
              onClick={onRowClick ? () => onRowClick(row) : undefined}
            >
              {visible.map((c) => (
                <td
                  key={c.id}
                  className={cn("truncate px-3 py-2 align-middle", c.className)}
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

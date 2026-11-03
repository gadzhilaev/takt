"use client";

import { AppIcon } from "@/components/ui/app-icon";
import { useEffect, useMemo, useRef, useState } from "react";
import { cn } from "@/lib/utils";

export type MultiOption = { value: string; label: string };

export function MultiSelect({
  values,
  onChange,
  options,
  placeholder = "Не назначены",
  searchPlaceholder = "Поиск…",
  id,
  "aria-label": ariaLabel,
  className,
  minCount = 0,
}: {
  values: string[];
  onChange: (next: string[]) => void;
  options: MultiOption[];
  placeholder?: string;
  searchPlaceholder?: string;
  id?: string;
  "aria-label"?: string;
  className?: string;
  /** When set, deselecting is blocked once selection would fall below this count. */
  minCount?: number;
}) {
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");
  const rootRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    function onDoc(e: MouseEvent) {
      if (!rootRef.current?.contains(e.target as Node)) setOpen(false);
    }
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") setOpen(false);
    }
    document.addEventListener("mousedown", onDoc);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDoc);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  const selected = useMemo(
    () => options.filter((o) => values.includes(o.value)),
    [options, values]
  );
  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase();
    if (!needle) return options;
    return options.filter((o) => o.label.toLowerCase().includes(needle));
  }, [options, q]);

  function toggle(value: string) {
    if (values.includes(value)) {
      if (values.length <= minCount) return;
      onChange(values.filter((v) => v !== value));
    } else {
      onChange([...values, value]);
    }
  }

  return (
    <div ref={rootRef} className={cn("relative", className)}>
      <button
        id={id}
        type="button"
        aria-label={ariaLabel}
        aria-expanded={open}
        aria-haspopup="listbox"
        className="field flex min-h-10 w-full items-center justify-between gap-2 px-3 text-left text-sm"
        onClick={() => setOpen((v) => !v)}
      >
        <span className="min-w-0 flex-1 truncate">
          {selected.length ? selected.map((s) => s.label).join(", ") : placeholder}
        </span>
        <AppIcon name="chevron-down" size={16} className="shrink-0 opacity-60" />
      </button>
      {open && (
        <div
          role="listbox"
          aria-multiselectable
          className="absolute z-[80] mt-1 w-full overflow-hidden rounded-[var(--radius)] border border-hairline bg-[var(--surface)] shadow-sm"
        >
          {options.length > 5 && (
            <div className="border-b border-hairline p-2">
              <input
                className="field h-8"
                value={q}
                onChange={(e) => setQ(e.target.value)}
                placeholder={searchPlaceholder}
                autoFocus
              />
            </div>
          )}
          <ul className="max-h-56 overflow-y-auto p-1">
            {filtered.map((opt) => {
              const on = values.includes(opt.value);
              return (
                <li key={opt.value}>
                  <button
                    type="button"
                    role="option"
                    aria-selected={on}
                    className="flex w-full items-center gap-2 rounded-[var(--radius-sm)] px-2 py-2 text-left text-sm hover:bg-[var(--surface-2)]"
                    onClick={() => toggle(opt.value)}
                  >
                    <span
                      className={cn(
                        "flex h-4 w-4 items-center justify-center rounded border border-hairline",
                        on && "border-[var(--accent)] bg-[var(--accent)] text-[var(--accent-fg)]"
                      )}
                    >
                      {on && <AppIcon name="check" size={16} />}
                    </span>
                    {opt.label}
                  </button>
                </li>
              );
            })}
            {!filtered.length && <li className="px-3 py-2 text-sm text-muted">Ничего не найдено</li>}
          </ul>
          {selected.length > 0 && (
            <div className="flex flex-wrap gap-1 border-t border-hairline p-2">
              {selected.map((s) => (
                <button
                  key={s.value}
                  type="button"
                  className="inline-flex items-center gap-1 rounded-full bg-[var(--surface-2)] px-2 py-0.5 text-xs"
                  onClick={() => toggle(s.value)}
                >
                  {s.label}
                  <AppIcon name="close" size={16} />
                </button>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

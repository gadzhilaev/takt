"use client";

import { Monitor, Moon, Sun } from "lucide-react";
import { useTheme } from "next-themes";
import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

const options = [
  { value: "light", label: "Светлая", icon: Sun },
  { value: "dark", label: "Тёмная", icon: Moon },
  { value: "system", label: "Системная", icon: Monitor },
] as const;

export function ThemeMenu() {
  const { theme, setTheme } = useTheme();
  const [open, setOpen] = useState(false);
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);
  if (!mounted) {
    return <Button variant="ghost" size="icon" aria-label="Тема" />;
  }
  const current = options.find((o) => o.value === theme) ?? options[2];
  const Icon = current.icon;
  return (
    <div className="relative">
      <Button variant="ghost" size="icon" aria-label="Тема" onClick={() => setOpen((v) => !v)}>
        <Icon className="h-4 w-4" />
      </Button>
      {open && (
        <>
          <button className="fixed inset-0 z-40 cursor-default" aria-label="Закрыть" onClick={() => setOpen(false)} />
          <div className="absolute right-0 z-50 mt-1.5 w-40 overflow-hidden rounded-[var(--radius-lg)] border border-hairline bg-[var(--surface)] shadow-soft">
            {options.map(({ value, label, icon: ItemIcon }) => (
              <button
                key={value}
                className={cn(
                  "flex w-full items-center gap-2 px-3 py-2 text-left text-[13px] hover:bg-[var(--surface-2)]",
                  theme === value && "bg-[var(--accent-soft)] font-semibold text-[var(--accent)]"
                )}
                onClick={() => {
                  setTheme(value);
                  setOpen(false);
                }}
              >
                <ItemIcon className="h-3.5 w-3.5" />
                {label}
              </button>
            ))}
          </div>
        </>
      )}
    </div>
  );
}

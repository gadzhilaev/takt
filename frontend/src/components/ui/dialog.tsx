"use client";

import * as DialogPrimitive from "@radix-ui/react-dialog";
import { X } from "lucide-react";
import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

export function Dialog({
  open,
  onOpenChange,
  title,
  children,
  className,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  children: ReactNode;
  className?: string;
}) {
  return (
    <DialogPrimitive.Root open={open} onOpenChange={onOpenChange}>
      <DialogPrimitive.Portal>
        <DialogPrimitive.Overlay className="fixed inset-0 z-[70] bg-black/30 data-[state=open]:animate-in data-[state=closed]:animate-out" />
        <DialogPrimitive.Content
          className={cn(
            "fixed left-1/2 top-1/2 z-[71] w-[min(100%-1.5rem,24rem)] -translate-x-1/2 -translate-y-1/2 rounded-[var(--radius-lg)] border border-hairline bg-[var(--surface)] p-4 shadow-sm focus:outline-none",
            className
          )}
        >
          <div className="mb-3 flex items-start justify-between gap-2">
            <DialogPrimitive.Title className="text-base font-semibold">{title}</DialogPrimitive.Title>
            <DialogPrimitive.Close className="rounded p-1 text-muted hover:bg-[var(--surface-2)] hover:text-foreground" aria-label="Закрыть">
              <X className="h-4 w-4" />
            </DialogPrimitive.Close>
          </div>
          {children}
        </DialogPrimitive.Content>
      </DialogPrimitive.Portal>
    </DialogPrimitive.Root>
  );
}

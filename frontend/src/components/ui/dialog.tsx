"use client";

import { AppIcon } from "@/components/ui/app-icon";
import * as DialogPrimitive from "@radix-ui/react-dialog";
import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

export function Dialog({
  open,
  onOpenChange,
  title,
  children,
  className,
  centerTitle = false,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  children: ReactNode;
  className?: string;
  centerTitle?: boolean;
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
          <div className={cn("mb-3 flex items-center gap-2", centerTitle && "relative justify-center")}>
            <DialogPrimitive.Title
              className={cn(
                "min-w-0 flex-1 text-base font-semibold",
                centerTitle && "flex-none text-center pr-8 pl-8"
              )}
            >
              {title}
            </DialogPrimitive.Title>
            <DialogPrimitive.Close
              className={cn(
                "rounded p-1 text-muted hover:bg-[var(--surface-2)] hover:text-foreground",
                centerTitle && "absolute right-0 top-1/2 -translate-y-1/2"
              )}
              aria-label="Закрыть"
            >
              <AppIcon name="close" size={16} />
            </DialogPrimitive.Close>
          </div>
          {children}
        </DialogPrimitive.Content>
      </DialogPrimitive.Portal>
    </DialogPrimitive.Root>
  );
}

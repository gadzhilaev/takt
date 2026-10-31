"use client";

import * as React from "react";
import { AppIcon } from "@/components/ui/app-icon";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";

/** Password field with show/hide toggle (eye). */
export const PasswordInput = React.forwardRef<
  HTMLInputElement,
  Omit<React.InputHTMLAttributes<HTMLInputElement>, "type">
>(({ className, ...props }, ref) => {
  const [show, setShow] = React.useState(false);
  return (
    <div className="relative">
      <Input
        ref={ref}
        type={show ? "text" : "password"}
        className={cn("pr-10", className)}
        {...props}
      />
      <button
        type="button"
        className="absolute right-1.5 top-1/2 -translate-y-1/2 rounded-[var(--radius-sm)] p-1.5 text-muted hover:bg-[var(--surface-2)]"
        onClick={() => setShow((s) => !s)}
        aria-label={show ? "Скрыть пароль" : "Показать пароль"}
        tabIndex={-1}
      >
        {show ? <AppIcon name="eye-off" size={16} /> : <AppIcon name="eye" size={16} />}
      </button>
    </div>
  );
});
PasswordInput.displayName = "PasswordInput";

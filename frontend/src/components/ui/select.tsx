"use client";

import { AppIcon } from "@/components/ui/app-icon";
import * as SelectPrimitive from "@radix-ui/react-select";
import { cn } from "@/lib/utils";

export type SelectOption = { value: string; label: string; disabled?: boolean };

export function Select({
  value,
  onValueChange,
  options,
  placeholder = "Выберите",
  disabled,
  className,
  id,
  "aria-label": ariaLabel,
}: {
  value: string;
  onValueChange: (value: string) => void;
  options: SelectOption[];
  placeholder?: string;
  disabled?: boolean;
  className?: string;
  id?: string;
  "aria-label"?: string;
}) {
  return (
    <SelectPrimitive.Root value={value || undefined} onValueChange={onValueChange} disabled={disabled}>
      <SelectPrimitive.Trigger
        id={id}
        aria-label={ariaLabel}
        className={cn(
          "field flex h-10 w-full items-center justify-between gap-2 px-3 text-left text-sm",
          !value && "text-muted",
          className
        )}
      >
        <SelectPrimitive.Value placeholder={placeholder} />
        <SelectPrimitive.Icon>
          <AppIcon name="chevron-down" size={16} className="shrink-0 opacity-60" />
        </SelectPrimitive.Icon>
      </SelectPrimitive.Trigger>
      <SelectPrimitive.Portal>
        <SelectPrimitive.Content
          position="popper"
          sideOffset={4}
          className="z-[80] max-h-64 min-w-[var(--radix-select-trigger-width)] overflow-hidden rounded-[var(--radius)] border border-hairline bg-[var(--surface)] shadow-sm"
        >
          <SelectPrimitive.Viewport className="p-1">
            {options.map((opt) => (
              <SelectPrimitive.Item
                key={opt.value}
                value={opt.value}
                disabled={opt.disabled}
                className="relative flex cursor-pointer select-none items-center rounded-[var(--radius-sm)] py-2 pl-8 pr-3 text-sm outline-none data-[disabled]:opacity-40 data-[highlighted]:bg-[var(--surface-2)]"
              >
                <span className="absolute left-2 flex h-4 w-4 items-center justify-center">
                  <SelectPrimitive.ItemIndicator>
                    <AppIcon name="check" size={16} className="text-[var(--accent)]" />
                  </SelectPrimitive.ItemIndicator>
                </span>
                <SelectPrimitive.ItemText>{opt.label}</SelectPrimitive.ItemText>
              </SelectPrimitive.Item>
            ))}
          </SelectPrimitive.Viewport>
        </SelectPrimitive.Content>
      </SelectPrimitive.Portal>
    </SelectPrimitive.Root>
  );
}

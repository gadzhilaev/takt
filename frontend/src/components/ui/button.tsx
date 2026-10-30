import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-1.5 rounded-[var(--radius)] text-sm font-semibold transition-colors focus-visible:outline-none disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        default: "bg-[var(--accent)] text-[var(--accent-fg)] hover:brightness-[0.96] active:brightness-[0.92]",
        secondary:
          "border border-hairline bg-[var(--surface)] text-foreground hover:bg-[var(--surface-2)]",
        ghost: "text-[var(--muted-fg)] hover:bg-[var(--surface-2)] hover:text-foreground",
        destructive: "bg-[var(--danger)] text-white hover:brightness-95",
      },
      size: {
        default: "h-9 min-h-[36px] px-3.5 py-1.5",
        sm: "h-8 min-h-[32px] px-2.5 text-xs",
        icon: "h-9 w-9 min-h-[36px] min-w-[36px]",
        lg: "h-10 min-h-[40px] px-4 text-sm",
      },
    },
    defaultVariants: { variant: "default", size: "default" },
  }
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : "button";
    return <Comp className={cn(buttonVariants({ variant, size, className }))} ref={ref} {...props} />;
  }
);
Button.displayName = "Button";

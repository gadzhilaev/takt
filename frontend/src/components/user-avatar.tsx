import { getInitials } from "@/lib/utils";
import { cn } from "@/lib/utils";

/** Muted brand-adjacent palette — no loud purple/pink splash. */
const colors = ["#4B8CAF", "#7892B2", "#4B9873", "#9774BD", "#A8895C"];

/** Integer rem sizes → crisp device pixels (avoid half-px blur on circles). */
const sizeMap: Record<number, string> = {
  5: "h-5 w-5 text-[8px]",
  6: "h-7 w-7 text-[9px]",
  7: "h-7 w-7 text-[9px]",
  8: "h-8 w-8 text-[11px]",
  9: "h-9 w-9 text-xs",
  10: "h-10 w-10 text-sm",
  14: "h-14 w-14 text-base",
  24: "h-24 w-24 text-2xl",
  28: "h-28 w-28 text-2xl",
};

export function UserAvatar({
  name,
  avatarUrl,
  size = 8,
  className,
  title,
}: {
  name: string;
  avatarUrl?: string | null;
  size?: number;
  className?: string;
  title?: string;
}) {
  const cls = sizeMap[size] ?? sizeMap[8];
  // Solid 1px border (not box-shadow ring) keeps small circles sharp.
  const shape = cn(
    "box-border shrink-0 overflow-hidden rounded-full border border-[var(--border-strong)] leading-none",
    cls,
    className
  );

  if (avatarUrl) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={avatarUrl}
        alt={name}
        title={title ?? name}
        draggable={false}
        className={cn(shape, "object-cover")}
      />
    );
  }
  const color = colors[name.charCodeAt(0) % colors.length];
  return (
    <span
      className={cn(shape, "inline-flex items-center justify-center font-semibold text-white")}
      style={{ backgroundColor: color }}
      title={title ?? name}
      role="img"
      aria-label={name}
    >
      <span className="translate-y-px select-none">{getInitials(name)}</span>
    </span>
  );
}

import { getInitials } from "@/lib/utils";
import { cn } from "@/lib/utils";

/** Muted brand-adjacent palette — no loud purple/pink splash. */
const colors = ["#315F72", "#4A6B7C", "#5C7380", "#3D5A4C", "#6B5E4E"];

const sizeMap: Record<number, string> = {
  6: "h-6 w-6 text-[10px]",
  7: "h-7 w-7 text-[10px]",
  8: "h-8 w-8 text-xs",
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
  if (avatarUrl) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={avatarUrl}
        alt={name}
        title={title ?? name}
        className={cn(`${cls} rounded-full object-cover ring-1 ring-[var(--border)]`, className)}
      />
    );
  }
  const color = colors[name.charCodeAt(0) % colors.length];
  return (
    <span
      className={cn(
        `inline-flex items-center justify-center rounded-full font-semibold text-white ring-1 ring-[var(--border)] ${cls}`,
        className
      )}
      style={{ backgroundColor: color }}
      title={title ?? name}
      role="img"
      aria-label={name}
    >
      {getInitials(name)}
    </span>
  );
}

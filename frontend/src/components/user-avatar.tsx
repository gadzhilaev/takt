import { getInitials } from "@/lib/utils";

/** Muted brand-adjacent palette — no loud purple/pink splash. */
const colors = ["#315F72", "#4A6B7C", "#5C7380", "#3D5A4C", "#6B5E4E"];

const sizeMap: Record<number, string> = {
  6: "h-6 w-6 text-[10px]",
  7: "h-7 w-7 text-[10px]",
  8: "h-8 w-8 text-xs",
  9: "h-9 w-9 text-xs",
  10: "h-10 w-10 text-sm",
};

export function UserAvatar({
  name,
  avatarUrl,
  size = 8,
}: {
  name: string;
  avatarUrl?: string | null;
  size?: number;
}) {
  const cls = sizeMap[size] ?? sizeMap[8];
  if (avatarUrl) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={avatarUrl}
        alt={name}
        className={`${cls} rounded-full object-cover ring-1 ring-[var(--border)]`}
      />
    );
  }
  const color = colors[name.charCodeAt(0) % colors.length];
  return (
    <span
      className={`inline-flex items-center justify-center rounded-full font-semibold text-white ring-1 ring-[var(--border)] ${cls}`}
      style={{ backgroundColor: color }}
      aria-hidden
    >
      {getInitials(name)}
    </span>
  );
}

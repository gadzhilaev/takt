import { getInitials } from "@/lib/utils";

const colors = ["#6366f1", "#ec4899", "#14b8a6", "#f59e0b", "#3b82f6"];

export function UserAvatar({
  name,
  avatarUrl,
  size = 8,
}: {
  name: string;
  avatarUrl?: string | null;
  size?: number;
}) {
  const cls = `h-${size} w-${size}`;
  if (avatarUrl) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img src={avatarUrl} alt={name} className={`${cls} rounded-full object-cover ring-2 ring-white`} />
    );
  }
  const color = colors[name.charCodeAt(0) % colors.length];
  return (
    <span
      className={`inline-flex items-center justify-center rounded-full text-xs font-semibold text-white ring-2 ring-white`}
      style={{ backgroundColor: color, width: size * 4, height: size * 4 }}
      aria-hidden
    >
      {getInitials(name)}
    </span>
  );
}

"use client";

import { AppIcon } from "@/components/ui/app-icon";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { cn } from "@/lib/utils";

/** Bell button that opens the notifications drawer (managed by AppShell). */
export function NotificationsMenu({
  className,
  onOpen,
}: {
  className?: string;
  onOpen: () => void;
}) {
  const { data } = useQuery({
    queryKey: ["notifications"],
    queryFn: () =>
      api<{ items: unknown[]; unread: number }>("/api/v1/notifications?page_size=1"),
    staleTime: 15_000,
    refetchInterval: 60_000,
  });

  const unread = data?.unread ?? 0;

  return (
    <button
      type="button"
      aria-label="Уведомления"
      className={cn(
        "relative inline-flex h-8 w-8 items-center justify-center rounded-[var(--radius)] text-muted hover:bg-[var(--surface-2)] hover:text-foreground",
        className
      )}
      onClick={onOpen}
    >
      <AppIcon name="notifications" size={16} />
      {unread > 0 && (
        <span className="absolute right-1 top-1 h-1.5 w-1.5 rounded-full bg-[var(--priority-urgent)]" />
      )}
    </button>
  );
}

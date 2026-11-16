"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { CheckinForm } from "@/components/checkin-form";
import { useCurrentCheckins } from "@/components/checkin-banner";
import { EmptyState } from "@/components/ui/empty-state";
import { Skeleton } from "@/components/ui/skeleton";
import { api } from "@/lib/api";
import type { Checkin } from "@/lib/rhythm";

/** Экран чек-ина: по ссылке из push (`/app/checkin/{id}`) или текущий (`/app/checkin`). */
export function CheckinPage({ checkinId }: { checkinId?: string }) {
  const router = useRouter();
  const current = useCurrentCheckins();
  const one = useQuery({
    queryKey: ["rhythm", "checkin", checkinId],
    queryFn: () => api<{ checkin: Checkin }>(`/api/v1/rhythm/checkins/${checkinId}`),
    enabled: !!checkinId,
  });
  const checkin: Checkin | undefined = checkinId
    ? one.data?.checkin
    : (current.data?.checkins.find((c) => c.status === "pending") ?? current.data?.checkins[0]);
  const loading = checkinId ? one.isLoading : current.isLoading;

  return (
    <div className="mx-auto w-full max-w-xl overflow-y-auto pb-6">
      <h1 className="text-lg font-semibold tracking-tight">Чек-ин на сегодня</h1>
      {checkin?.project && (
        <p className="mt-0.5 text-sm text-muted">
          Проект{" "}
          <Link className="text-[var(--accent)] hover:underline" href={`/app/projects/${checkin.project.id}`}>
            {checkin.project.name}
          </Link>
        </p>
      )}
      <div className="mt-4">
        {loading && <Skeleton className="h-48 w-full" />}
        {!loading && !checkin && (
          <EmptyState
            title="На сегодня всё"
            description="Новых вопросов по задачам нет. Чек-ин придёт в рабочий день."
          />
        )}
        {!loading && checkin && (
          <CheckinForm
            key={checkin.id}
            checkin={checkin}
            onDone={() =>
              router.push(checkin.project ? `/app/projects/${checkin.project.id}` : "/app/projects")
            }
          />
        )}
      </div>
    </div>
  );
}

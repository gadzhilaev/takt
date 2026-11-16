"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { CheckinForm } from "@/components/checkin-form";
import { AppIcon } from "@/components/ui/app-icon";
import { Button } from "@/components/ui/button";
import { Dialog } from "@/components/ui/dialog";
import { api } from "@/lib/api";
import { bannerText, type CurrentCheckins } from "@/lib/rhythm";

export const CURRENT_CHECKINS_KEY = ["rhythm", "current"] as const;

export function useCurrentCheckins() {
  return useQuery({
    queryKey: CURRENT_CHECKINS_KEY,
    queryFn: () => api<CurrentCheckins>("/api/v1/rhythm/checkins/current"),
    refetchInterval: 5 * 60_000,
    refetchOnWindowFocus: true,
    staleTime: 30_000,
  });
}

/** Спокойный баннер «Чек-ин на сегодня» над доской и «Моими задачами». */
export function CheckinBanner() {
  const { data } = useCurrentCheckins();
  const [openId, setOpenId] = useState<string | null>(null);
  const text = bannerText(data);
  const pending = data?.checkins.filter((c) => c.status === "pending") ?? [];
  const open = data?.checkins.find((c) => c.id === openId) ?? null;

  if (!text && !open) return null;

  return (
    <>
      {text && (
        <div className="mb-3 flex items-center gap-3 rounded-[var(--radius)] border border-[var(--accent)]/30 bg-[var(--accent-soft)] px-3 py-2.5">
          <AppIcon name="circle-check" size={18} className="shrink-0 text-[var(--accent)]" />
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-semibold text-foreground">{text}</p>
            <p className="truncate text-xs text-muted">
              Ответьте одним нажатием — задачи обновятся сами
            </p>
          </div>
          <Button size="sm" onClick={() => setOpenId(pending[0]?.id ?? null)}>
            Ответить
          </Button>
        </div>
      )}
      <Dialog
        open={!!open}
        onOpenChange={(v) => !v && setOpenId(null)}
        title={open?.project ? `Чек-ин · ${open.project.name}` : "Чек-ин"}
      >
        {open && (
          <CheckinForm
            key={open.id}
            checkin={open}
            onDone={() => {
              const next = pending.find((c) => c.id !== open.id);
              setOpenId(next?.id ?? null);
            }}
          />
        )}
      </Dialog>
    </>
  );
}

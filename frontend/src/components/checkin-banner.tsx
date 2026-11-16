"use client";

import { useState } from "react";
import { usePathname } from "next/navigation";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { CheckinForm } from "@/components/checkin-form";
import { AppIcon } from "@/components/ui/app-icon";
import { Button } from "@/components/ui/button";
import { Dialog } from "@/components/ui/dialog";
import { api, messageFromApiError } from "@/lib/api";
import { bannerText, startProjectId, type Checkin, type CurrentCheckins } from "@/lib/rhythm";

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
  const qc = useQueryClient();
  const pathname = usePathname();
  const [openId, setOpenId] = useState<string | null>(null);
  const [started, setStarted] = useState<Checkin | null>(null);
  const [starting, setStarting] = useState(false);
  const [startErr, setStartErr] = useState("");
  const text = bannerText(data);
  const pending = data?.checkins.filter((c) => c.status === "pending") ?? [];
  const open =
    (started && started.id === openId ? started : null) ??
    data?.checkins.find((c) => c.id === openId) ??
    null;
  const currentProjectId = pathname?.match(/^\/app\/projects\/([^/?]+)/)?.[1] ?? null;
  const startId = startProjectId(data, currentProjectId);

  async function startNow() {
    if (!startId) return;
    setStarting(true);
    setStartErr("");
    try {
      const res = await api<{ checkin: Checkin }>(
        `/api/v1/rhythm/checkins/start?project_id=${encodeURIComponent(startId)}`,
        { method: "POST" }
      );
      setStarted(res.checkin);
      setOpenId(res.checkin.id);
      qc.invalidateQueries({ queryKey: CURRENT_CHECKINS_KEY });
    } catch (e) {
      setStartErr(messageFromApiError(e) || "Не удалось начать чек-ин");
    } finally {
      setStarting(false);
    }
  }

  if (!text && !open && !startId) return null;

  return (
    <>
      {!text && startId && (
        <div className="mb-3 flex items-center justify-end gap-2">
          {startErr && <span className="text-xs text-[var(--danger)]">{startErr}</span>}
          <Button variant="secondary" size="sm" disabled={starting} onClick={() => void startNow()}>
            <AppIcon name="circle-check" size={16} />
            {starting ? "Готовим…" : "Пройти чек-ин сейчас"}
          </Button>
        </div>
      )}
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
              setStarted(null);
              setOpenId(next?.id ?? null);
            }}
          />
        )}
      </Dialog>
    </>
  );
}

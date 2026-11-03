"use client";

import { useEffect, useState } from "react";

/** Wall clock that ticks so relative time labels refresh without remount. */
export function useTickingNow(enabled = true, intervalMs = 30_000): number {
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    if (!enabled) return;
    setNow(Date.now());
    const id = window.setInterval(() => setNow(Date.now()), intervalMs);
    return () => window.clearInterval(id);
  }, [enabled, intervalMs]);

  return now;
}

"use client";

import { useEffect, useState, type Dispatch, type SetStateAction } from "react";

/** Keep UI draft across Fast Refresh / remount (not across browsers). */
export function useSessionState<T extends string | number>(
  key: string,
  initial: T
): [T, Dispatch<SetStateAction<T>>] {
  const [value, setValue] = useState<T>(() => {
    if (typeof window === "undefined") return initial;
    try {
      const raw = sessionStorage.getItem(key);
      if (raw == null) return initial;
      if (typeof initial === "number") {
        const n = Number(raw);
        return (Number.isFinite(n) ? n : initial) as T;
      }
      return raw as T;
    } catch {
      return initial;
    }
  });

  useEffect(() => {
    try {
      sessionStorage.setItem(key, String(value));
    } catch {
      /* ignore quota / private mode */
    }
  }, [key, value]);

  return [value, setValue];
}

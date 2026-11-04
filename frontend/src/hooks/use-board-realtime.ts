"use client";

import { useQueryClient } from "@tanstack/react-query";
import { useEffect, useRef } from "react";
import { wsUrl } from "@/lib/api";

function projectIdFromWsPayload(raw: string): string | null {
  try {
    const msg = JSON.parse(raw) as {
      data?: { project_id?: string | null; task?: { project_id?: string | null } };
    };
    const d = msg.data;
    if (d?.project_id) return String(d.project_id);
    if (d?.task?.project_id) return String(d.task.project_id);
  } catch {
    /* ignore malformed */
  }
  return null;
}

/** Live board updates via WebSocket + visibility refetch as fallback. */
export function useBoardRealtime(projectId: string) {
  const qc = useQueryClient();
  const projectIdRef = useRef(projectId);
  projectIdRef.current = projectId;

  useEffect(() => {
    const url = wsUrl();
    if (!url || !projectId) return;

    let ws: WebSocket | null = null;
    let closed = false;
    let attempt = 0;
    let reconnectTimer: ReturnType<typeof setTimeout> | null = null;

    function invalidateBoard() {
      const id = projectIdRef.current;
      void qc.invalidateQueries({ queryKey: ["tasks", id] });
      void qc.invalidateQueries({ queryKey: ["statuses", id] });
    }

    function connect() {
      if (closed) return;
      ws = new WebSocket(url);
      ws.onopen = () => {
        attempt = 0;
      };
      ws.onmessage = (ev) => {
        const raw = typeof ev.data === "string" ? ev.data : "";
        const pid = projectIdFromWsPayload(raw);
        if (pid && pid !== projectIdRef.current) return;
        invalidateBoard();
      };
      ws.onclose = () => {
        if (closed) return;
        const delay = Math.min(30_000, 1000 * 2 ** Math.min(attempt, 5));
        attempt += 1;
        reconnectTimer = setTimeout(connect, delay);
      };
      ws.onerror = () => {
        try {
          ws?.close();
        } catch {
          /* ignore */
        }
      };
    }

    function onVisible() {
      if (document.visibilityState !== "visible") return;
      invalidateBoard();
    }

    connect();
    document.addEventListener("visibilitychange", onVisible);
    window.addEventListener("focus", onVisible);

    return () => {
      closed = true;
      if (reconnectTimer) clearTimeout(reconnectTimer);
      document.removeEventListener("visibilitychange", onVisible);
      window.removeEventListener("focus", onVisible);
      try {
        ws?.close();
      } catch {
        /* ignore */
      }
    };
  }, [qc, projectId]);
}

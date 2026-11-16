"use client";

import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { DELETE_PREVIEW_PATH, deletePreviewLines, type DeletePreview } from "@/lib/account-delete";

/** Заранее показывает, что станет с проектами после удаления аккаунта. */
export function AccountDeletePreview({ className }: { className?: string }) {
  const [preview, setPreview] = useState<DeletePreview | null | undefined>(undefined);

  useEffect(() => {
    let cancelled = false;
    api<DeletePreview>(DELETE_PREVIEW_PATH)
      .then((p) => !cancelled && setPreview(p))
      .catch(() => !cancelled && setPreview(null));
    return () => {
      cancelled = true;
    };
  }, []);

  if (preview === undefined) {
    return <p className={`text-xs text-muted ${className ?? ""}`}>Проверяем ваши проекты…</p>;
  }
  if (preview === null) return null;
  if (preview.blocked) {
    return <p className={`text-xs text-[var(--danger)] ${className ?? ""}`}>{preview.blocked.message}</p>;
  }
  const lines = deletePreviewLines(preview);
  if (!lines.length) return null;
  return (
    <ul className={`list-disc space-y-1 pl-4 text-xs text-foreground/90 ${className ?? ""}`}>
      {lines.map((line) => (
        <li key={line}>{line}</li>
      ))}
    </ul>
  );
}

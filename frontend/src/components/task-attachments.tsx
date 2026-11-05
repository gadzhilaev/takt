"use client";

import { AppIcon } from "@/components/ui/app-icon";
import {
  assertAttachmentSize,
  formatBytes,
  deleteTaskAttachment,
  uploadTaskAttachment,
} from "@/lib/attachments";
import type { TaskAttachment } from "@/lib/types";
import { cn } from "@/lib/utils";
import { useEffect, useRef, useState } from "react";

export function TaskAttachmentsPanel({
  taskId,
  attachments,
  editable = false,
  onChanged,
}: {
  taskId: string;
  attachments: TaskAttachment[];
  editable?: boolean;
  onChanged?: () => void;
}) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [lightbox, setLightbox] = useState<TaskAttachment | null>(null);

  async function onPick(files: FileList | null) {
    if (!files?.length) return;
    setBusy(true);
    setError("");
    try {
      const list = Array.from(files);
      for (const file of list) assertAttachmentSize(file);
      // Upload in parallel so several files finish together.
      await Promise.all(list.map((file) => uploadTaskAttachment(taskId, file)));
      onChanged?.();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Не удалось загрузить");
    } finally {
      setBusy(false);
      if (inputRef.current) inputRef.current.value = "";
    }
  }

  async function onRemove(att: TaskAttachment) {
    if (!confirm(`Удалить «${att.filename}»?`)) return;
    setBusy(true);
    setError("");
    try {
      await deleteTaskAttachment(taskId, att.id);
      onChanged?.();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Не удалось удалить");
    } finally {
      setBusy(false);
    }
  }

  // View mode without files — hide the whole block (no «Нет вложений»).
  if (!editable && !attachments.length) {
    return null;
  }

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between gap-2">
        <p className="label-text mb-0">Файлы</p>
        {editable && (
          <>
            <button
              type="button"
              className="text-[13px] font-semibold text-[var(--accent)] disabled:opacity-50"
              disabled={busy}
              onClick={() => inputRef.current?.click()}
            >
              {busy ? "Загрузка…" : "Прикрепить"}
            </button>
            <input
              ref={inputRef}
              type="file"
              className="hidden"
              multiple
              onChange={(e) => void onPick(e.target.files)}
            />
          </>
        )}
      </div>
      {editable && (
        <p className="text-[11px] text-muted">Можно несколько файлов, до 20 МБ каждый</p>
      )}
      <ul className="space-y-1.5">
        {attachments.map((att) => (
          <li
            key={att.id}
            className="flex items-center gap-2 rounded-[var(--radius)] border border-hairline bg-[var(--surface-2)] px-2 py-1.5"
          >
            {att.is_image && att.preview_url ? (
              <button
                type="button"
                className="h-12 w-12 shrink-0 overflow-hidden rounded-[var(--radius)] bg-[var(--surface)]"
                onClick={() => setLightbox(att)}
                title="Открыть превью"
              >
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={att.preview_url}
                  alt={att.filename}
                  className="h-full w-full object-cover"
                />
              </button>
            ) : (
              <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-[var(--radius)] bg-[var(--surface)] text-muted">
                <AppIcon name="copy" size={18} />
              </span>
            )}
            <div className="min-w-0 flex-1">
              <a
                href={att.url}
                target="_blank"
                rel="noreferrer"
                className="block truncate text-[13px] font-medium text-foreground hover:underline"
              >
                {att.filename}
              </a>
              <p className="text-[11px] text-muted">{formatBytes(att.size_bytes)}</p>
            </div>
            {editable && (
              <button
                type="button"
                className="rounded p-1.5 text-muted hover:bg-[var(--danger-soft)] hover:text-[var(--danger)]"
                aria-label="Удалить файл"
                disabled={busy}
                onClick={() => void onRemove(att)}
              >
                <AppIcon name="delete" size={16} />
              </button>
            )}
          </li>
        ))}
      </ul>
      {error && <p className="text-sm text-[var(--danger)]">{error}</p>}

      {lightbox && (
        <div className="fixed inset-0 z-[80] flex items-center justify-center bg-black/70 p-4">
          <button
            type="button"
            className="absolute inset-0 cursor-default"
            aria-label="Закрыть"
            onClick={() => setLightbox(null)}
          />
          <div className="relative z-10 max-h-[90vh] max-w-[min(960px,100%)] overflow-hidden rounded-[var(--radius)] bg-black shadow-lg">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={lightbox.preview_url || lightbox.url}
              alt={lightbox.filename}
              className="max-h-[90vh] max-w-full object-contain"
            />
            <p className="truncate bg-black/60 px-3 py-2 text-center text-sm text-white">
              {lightbox.filename}
            </p>
            <button
              type="button"
              className="absolute right-2 top-2 rounded bg-black/50 p-1.5 text-white"
              aria-label="Закрыть"
              onClick={() => setLightbox(null)}
            >
              <AppIcon name="close" size={18} />
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

/** Pending local files before task exists (create form). */
export function PendingFilesList({
  files,
  onRemove,
  onAdd,
}: {
  files: File[];
  onRemove: (index: number) => void;
  onAdd: (files: FileList | null) => void;
}) {
  const inputRef = useRef<HTMLInputElement>(null);
  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between gap-2">
        <p className="label-text mb-0">Файлы</p>
        <button
          type="button"
          className="text-[13px] font-semibold text-[var(--accent)]"
          onClick={() => inputRef.current?.click()}
        >
          Прикрепить
        </button>
        <input
          ref={inputRef}
          type="file"
          className="hidden"
          multiple
          onChange={(e) => {
            onAdd(e.target.files);
            if (inputRef.current) inputRef.current.value = "";
          }}
        />
      </div>
      <p className="text-[11px] text-muted">Можно несколько файлов, до 20 МБ каждый</p>
      {files.length > 0 && (
        <ul className="space-y-1">
          {files.map((f, i) => (
            <li
              key={`${f.name}-${f.size}-${i}`}
              className={cn(
                "flex items-center gap-2 rounded-[var(--radius)] border border-hairline",
                "bg-[var(--surface-2)] px-2 py-1.5 text-[13px]"
              )}
            >
              {f.type.startsWith("image/") ? (
                <LocalImageThumb file={f} />
              ) : (
                <AppIcon name="copy" size={16} className="shrink-0 text-muted" />
              )}
              <span className="min-w-0 flex-1 truncate font-medium">{f.name}</span>
              <span className="shrink-0 text-[11px] text-muted">{formatBytes(f.size)}</span>
              <button
                type="button"
                className="rounded p-1 text-muted hover:text-[var(--danger)]"
                aria-label="Убрать"
                onClick={() => onRemove(i)}
              >
                <AppIcon name="close" size={14} />
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function LocalImageThumb({ file }: { file: File }) {
  const [src, setSrc] = useState<string | null>(null);
  useEffect(() => {
    const objectUrl = URL.createObjectURL(file);
    setSrc(objectUrl);
    return () => URL.revokeObjectURL(objectUrl);
  }, [file]);
  if (!src) {
    return <span className="h-10 w-10 shrink-0 rounded bg-[var(--surface)]" />;
  }
  // eslint-disable-next-line @next/next/no-img-element
  return <img src={src} alt="" className="h-10 w-10 shrink-0 rounded object-cover" />;
}

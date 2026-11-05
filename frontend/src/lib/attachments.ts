import { messageFromApiError } from "@/lib/api";
import type { Task, TaskAttachment } from "@/lib/types";

/** Must match backend `attachment_service.MAX_BYTES` and nginx `client_max_body_size`. */
export const MAX_ATTACHMENT_BYTES = 20 * 1024 * 1024;

function csrfToken(): string | undefined {
  if (typeof document === "undefined") return undefined;
  const match = document.cookie.match(/(?:^|; )csrf_token=([^;]+)/);
  return match ? decodeURIComponent(match[1]) : undefined;
}

export function assertAttachmentSize(file: File): void {
  if (file.size > MAX_ATTACHMENT_BYTES) {
    throw new Error(`«${file.name}» больше 20 МБ`);
  }
  if (file.size <= 0) {
    throw new Error(`«${file.name}» пустой`);
  }
}

export async function uploadTaskAttachment(
  taskId: string,
  file: File
): Promise<{ attachment: TaskAttachment; task: Task }> {
  assertAttachmentSize(file);
  const fd = new FormData();
  fd.append("file", file, file.name);
  const headers = new Headers();
  const csrf = csrfToken();
  if (csrf) headers.set("X-CSRF-Token", csrf);
  const res = await fetch(`/api/v1/tasks/${taskId}/attachments`, {
    method: "POST",
    credentials: "include",
    headers,
    body: fd,
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(messageFromApiError(err) || `Ошибка ${res.status}`);
  }
  return res.json();
}

export async function deleteTaskAttachment(taskId: string, attachmentId: string): Promise<Task> {
  const headers = new Headers();
  const csrf = csrfToken();
  if (csrf) headers.set("X-CSRF-Token", csrf);
  const res = await fetch(`/api/v1/tasks/${taskId}/attachments/${attachmentId}`, {
    method: "DELETE",
    credentials: "include",
    headers,
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(messageFromApiError(err) || `Ошибка ${res.status}`);
  }
  const body = await res.json();
  return body.task as Task;
}

export function formatBytes(n: number): string {
  if (n < 1024) return `${n} Б`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} КБ`;
  return `${(n / (1024 * 1024)).toFixed(1)} МБ`;
}

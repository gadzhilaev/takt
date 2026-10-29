const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? "";

function csrfToken(): string | undefined {
  if (typeof document === "undefined") return undefined;
  const match = document.cookie.match(/(?:^|; )csrf_token=([^;]+)/);
  return match ? decodeURIComponent(match[1]) : undefined;
}

type ApiOptions = RequestInit & { json?: unknown };

/** FastAPI `{detail:{error:{message}}}`, SlowAPI `{error:"…"}`, validation `detail:[]`. */
export function messageFromApiError(err: unknown): string | undefined {
  if (!err || typeof err !== "object") return undefined;
  const body = err as Record<string, unknown>;

  const nested = body.detail;
  if (nested && typeof nested === "object" && !Array.isArray(nested)) {
    const detail = nested as Record<string, unknown>;
    const error = detail.error;
    if (error && typeof error === "object" && !Array.isArray(error)) {
      const message = (error as Record<string, unknown>).message;
      if (typeof message === "string" && message.trim()) return message;
    }
    if (typeof detail.message === "string" && detail.message.trim()) return detail.message;
  }
  if (typeof nested === "string" && nested.trim()) return nested;
  if (Array.isArray(nested) && nested.length > 0) {
    const first = nested[0] as { msg?: unknown };
    if (typeof first?.msg === "string" && first.msg.trim()) return first.msg;
  }

  const top = body.error;
  if (typeof top === "string" && top.trim()) {
    if (/rate limit/i.test(top)) return "Слишком много попыток. Попробуйте через минуту";
    return top;
  }
  if (top && typeof top === "object" && !Array.isArray(top)) {
    const message = (top as Record<string, unknown>).message;
    if (typeof message === "string" && message.trim()) return message;
  }
  return undefined;
}

export async function api<T>(path: string, options: ApiOptions = {}): Promise<T> {
  const headers = new Headers(options.headers);
  if (options.json !== undefined) {
    headers.set("Content-Type", "application/json");
  }
  const token = csrfToken();
  if (token && options.method && options.method !== "GET") {
    headers.set("X-CSRF-Token", token);
  }
  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    credentials: "include",
    headers,
    body: options.json !== undefined ? JSON.stringify(options.json) : options.body,
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(messageFromApiError(err) ?? "Ошибка запроса");
  }
  if (res.status === 204) return undefined as T;
  return res.json() as Promise<T>;
}

export function wsUrl() {
  if (typeof window === "undefined") return "";
  const env = process.env.NEXT_PUBLIC_WS_URL;
  if (env) return env;
  const proto = window.location.protocol === "https:" ? "wss:" : "ws:";
  return `${proto}//${window.location.host}/ws`;
}

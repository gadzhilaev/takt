const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? "";

function csrfToken(): string | undefined {
  if (typeof document === "undefined") return undefined;
  const match = document.cookie.match(/(?:^|; )csrf_token=([^;]+)/);
  return match ? decodeURIComponent(match[1]) : undefined;
}

type ApiOptions = RequestInit & { json?: unknown; _retried?: boolean };

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
    return top;
  }
  if (top && typeof top === "object" && !Array.isArray(top)) {
    const message = (top as Record<string, unknown>).message;
    if (typeof message === "string" && message.trim()) return message;
  }
  return undefined;
}

let refreshInFlight: Promise<boolean> | null = null;

async function tryRefreshSession(): Promise<boolean> {
  if (typeof window === "undefined") return false;
  if (refreshInFlight) return refreshInFlight;
  refreshInFlight = (async () => {
    try {
      const headers = new Headers({ "Content-Type": "application/json" });
      const csrf = csrfToken();
      if (csrf) headers.set("X-CSRF-Token", csrf);
      const res = await fetch(`${API_BASE}/api/v1/auth/refresh`, {
        method: "POST",
        credentials: "include",
        headers,
        body: "{}",
      });
      return res.ok;
    } catch {
      return false;
    } finally {
      refreshInFlight = null;
    }
  })();
  return refreshInFlight;
}

async function clearAuthCookiesBestEffort() {
  try {
    const headers = new Headers({ "Content-Type": "application/json" });
    const csrf = csrfToken();
    if (csrf) headers.set("X-CSRF-Token", csrf);
    await fetch(`${API_BASE}/api/v1/auth/logout`, {
      method: "POST",
      credentials: "include",
      headers,
      body: "{}",
    });
  } catch {
    /* ignore — navigation still proceeds */
  }
}

function redirectToLogin() {
  if (typeof window === "undefined") return;
  const path = window.location.pathname + window.location.search;
  if (path.startsWith("/login") || path.startsWith("/register") || path.startsWith("/forgot-password")) {
    return;
  }
  const next = encodeURIComponent(path || "/app/projects");
  void clearAuthCookiesBestEffort().finally(() => {
    window.location.assign(`/login?next=${next}`);
  });
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

  if (res.status === 401) {
    const isAuthPath =
      path.includes("/auth/login") ||
      path.includes("/auth/refresh") ||
      path.includes("/auth/register") ||
      path.includes("/auth/forgot-password") ||
      path.includes("/auth/oauth");
    if (!isAuthPath && !options._retried) {
      const renewed = await tryRefreshSession();
      if (renewed) {
        return api<T>(path, { ...options, _retried: true });
      }
      redirectToLogin();
    } else if (!isAuthPath) {
      redirectToLogin();
    }
  }

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    const fromServer = messageFromApiError(err);
    throw new Error(fromServer || `Ошибка ${res.status}`);
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

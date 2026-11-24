import { api } from "@/lib/api";

function urlBase64ToUint8Array(base64String: string) {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");
  const raw = atob(base64);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}

export async function getPushStatus(): Promise<{
  supported: boolean;
  permission: NotificationPermission | "unsupported";
  configured: boolean;
  subscribed: boolean;
}> {
  if (typeof window === "undefined" || !("Notification" in window) || !("serviceWorker" in navigator)) {
    return { supported: false, permission: "unsupported", configured: false, subscribed: false };
  }
  let configured = false;
  try {
    const res = await api<{ public_key: string | null; configured: boolean }>(
      "/api/v1/notifications/push/vapid-public-key"
    );
    configured = !!res.configured && !!res.public_key;
  } catch {
    configured = false;
  }
  const permission = Notification.permission;
  let subscribed = false;
  if (permission === "granted") {
    try {
      const reg = await navigator.serviceWorker.getRegistration();
      const sub = await reg?.pushManager.getSubscription();
      subscribed = !!sub;
    } catch {
      subscribed = false;
    }
  }
  return { supported: true, permission, configured, subscribed };
}

export async function enableWebPush(): Promise<{ ok: boolean; message: string }> {
  if (!("Notification" in window) || !("serviceWorker" in navigator) || !("PushManager" in window)) {
    return { ok: false, message: "Браузер не поддерживает Web Push" };
  }
  const meta = await api<{ public_key: string | null; configured: boolean }>(
    "/api/v1/notifications/push/vapid-public-key"
  );
  if (!meta.configured || !meta.public_key) {
    return {
      ok: false,
      message: "Браузерные push пока недоступны. In-app уведомления работают как обычно.",
    };
  }
  // Reuse an existing grant without opening a browser permission prompt.
  const permission = Notification.permission === "granted"
    ? "granted"
    : await Notification.requestPermission();
  if (permission !== "granted") {
    return { ok: false, message: "Разрешение на уведомления не выдано" };
  }
  const reg = await navigator.serviceWorker.register("/sw.js");
  await navigator.serviceWorker.ready;
  let sub = await reg.pushManager.getSubscription();
  if (!sub) {
    sub = await reg.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(meta.public_key),
    });
  }
  const json = sub.toJSON();
  let lastError: unknown;
  // Registration is idempotent server-side. Retry transient network/server errors
  // so a granted browser permission is recovered without another user gesture.
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      await api("/api/v1/notifications/push/subscribe", {
        method: "POST",
        json: {
          endpoint: json.endpoint,
          keys: json.keys,
          user_agent: navigator.userAgent,
        },
      });
      return { ok: true, message: "Уведомления включены" };
    } catch (error) {
      lastError = error;
      if (attempt < 2) await new Promise((resolve) => window.setTimeout(resolve, 500 * (attempt + 1)));
    }
  }
  throw lastError instanceof Error ? lastError : new Error("Не удалось сохранить подписку на уведомления");
}

export async function disableWebPush(): Promise<void> {
  const reg = await navigator.serviceWorker.getRegistration();
  const sub = await reg?.pushManager.getSubscription();
  if (sub) {
    await api("/api/v1/notifications/push/unsubscribe", {
      method: "POST",
      json: { endpoint: sub.endpoint },
    }).catch(() => null);
    await sub.unsubscribe();
  }
}

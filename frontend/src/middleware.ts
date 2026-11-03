import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

const AUTH_COOKIES = ["access_token", "refresh_token"] as const;

/** Access JWT still valid (edge-safe, no crypto verify). */
function accessTokenAlive(request: NextRequest): boolean {
  const raw = request.cookies.get("access_token")?.value;
  if (!raw) return false;
  const parts = raw.split(".");
  if (parts.length < 2) return false;
  try {
    const json = atob(parts[1].replace(/-/g, "+").replace(/_/g, "/"));
    const payload = JSON.parse(json) as { exp?: number; type?: string };
    if (payload.type && payload.type !== "access") return false;
    if (typeof payload.exp !== "number") return false;
    return payload.exp * 1000 > Date.now() - 30_000;
  } catch {
    return false;
  }
}

function hasRefreshCookie(request: NextRequest): boolean {
  const raw = request.cookies.get("refresh_token")?.value;
  return Boolean(raw && raw.length > 20);
}

/**
 * Session can continue if access is valid OR refresh cookie exists.
 * Never clear refresh just because access expired — client/API will renew.
 */
function hasSession(request: NextRequest): boolean {
  return accessTokenAlive(request) || hasRefreshCookie(request);
}

function clearAuthCookies(res: NextResponse) {
  for (const name of AUTH_COOKIES) {
    res.cookies.set(name, "", { path: "/", maxAge: 0 });
  }
  res.cookies.set("csrf_token", "", { path: "/", maxAge: 0 });
}

export function middleware(request: NextRequest) {
  const { pathname, search } = request.nextUrl;
  const authed = hasSession(request);

  if (pathname === "/") {
    if (authed) {
      const url = request.nextUrl.clone();
      url.pathname = "/app/projects";
      url.search = "";
      return NextResponse.redirect(url);
    }
    return NextResponse.next();
  }

  // Only bounce away from login when access is still valid.
  // Refresh-only (or stale refresh) must not trap users in /app ↔ /login loops.
  // /forgot-password оставляем доступным залогиненным (задать пароль для OAuth-аккаунта).
  if ((pathname === "/login" || pathname === "/register") && accessTokenAlive(request)) {
    const next = request.nextUrl.searchParams.get("next");
    const url = request.nextUrl.clone();
    if (
      next &&
      next.startsWith("/") &&
      !next.startsWith("//") &&
      !next.startsWith("/login") &&
      !next.startsWith("/register")
    ) {
      try {
        const dest = new URL(next, request.nextUrl.origin);
        url.pathname = dest.pathname;
        url.search = dest.search;
      } catch {
        url.pathname = "/app/projects";
        url.search = "";
      }
    } else {
      url.pathname = "/app/projects";
      url.search = "";
    }
    return NextResponse.redirect(url);
  }

  if (pathname === "/app" || pathname.startsWith("/app/")) {
    if (!authed) {
      const url = request.nextUrl.clone();
      url.pathname = "/login";
      url.search = `?next=${encodeURIComponent(pathname + search)}`;
      const res = NextResponse.redirect(url);
      clearAuthCookies(res);
      return res;
    }
  }

  if (pathname === "/admin" || pathname.startsWith("/admin/")) {
    if (!authed) {
      const url = request.nextUrl.clone();
      url.pathname = "/login";
      url.search = `?next=${encodeURIComponent(pathname + search)}`;
      const res = NextResponse.redirect(url);
      clearAuthCookies(res);
      return res;
    }
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    "/",
    "/login",
    "/register",
    "/forgot-password",
    "/change-password",
    "/app",
    "/app/:path*",
    "/admin",
    "/admin/:path*",
  ],
};

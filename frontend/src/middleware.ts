import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

const AUTH_COOKIES = ["access_token", "refresh_token"] as const;

/** Cookie present AND JWT payload not expired (edge-safe, no crypto verify). */
function hasUsableSession(request: NextRequest): boolean {
  const raw = request.cookies.get("access_token")?.value;
  if (!raw) return false;
  const parts = raw.split(".");
  if (parts.length < 2) return false;
  try {
    const json = atob(parts[1].replace(/-/g, "+").replace(/_/g, "/"));
    const payload = JSON.parse(json) as { exp?: number; type?: string };
    if (payload.type && payload.type !== "access") return false;
    if (typeof payload.exp !== "number") return false;
    // 30s skew
    return payload.exp * 1000 > Date.now() - 30_000;
  } catch {
    return false;
  }
}

function clearAuthCookies(res: NextResponse) {
  for (const name of AUTH_COOKIES) {
    res.cookies.set(name, "", { path: "/", maxAge: 0 });
  }
}

export function middleware(request: NextRequest) {
  const { pathname, search } = request.nextUrl;
  const authed = hasUsableSession(request);
  const hadCookie = Boolean(request.cookies.get("access_token")?.value);

  // Public landing: always available without a valid session.
  if (pathname === "/") {
    if (authed) {
      const url = request.nextUrl.clone();
      url.pathname = "/app/projects";
      url.search = "";
      return NextResponse.redirect(url);
    }
    // Stale/invalid cookie must NOT bounce guests through /app → /login.
    if (hadCookie) {
      const res = NextResponse.next();
      clearAuthCookies(res);
      return res;
    }
    return NextResponse.next();
  }

  // Already signed in — skip auth forms (respect ?next= for invite links).
  if ((pathname === "/login" || pathname === "/register" || pathname === "/forgot-password") && authed) {
    const next = request.nextUrl.searchParams.get("next");
    const url = request.nextUrl.clone();
    if (next && next.startsWith("/") && !next.startsWith("//") && !next.startsWith("/login") && !next.startsWith("/register")) {
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

  // Protect workspace shell.
  if (pathname === "/app" || pathname.startsWith("/app/")) {
    if (!authed) {
      const url = request.nextUrl.clone();
      url.pathname = "/login";
      url.search = `?next=${encodeURIComponent(pathname + search)}`;
      const res = NextResponse.redirect(url);
      if (hadCookie) clearAuthCookies(res);
      return res;
    }
  }

  // Global platform admin console (role checked on API + client layout).
  if (pathname === "/admin" || pathname.startsWith("/admin/")) {
    if (!authed) {
      const url = request.nextUrl.clone();
      url.pathname = "/login";
      url.search = `?next=${encodeURIComponent(pathname + search)}`;
      const res = NextResponse.redirect(url);
      if (hadCookie) clearAuthCookies(res);
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

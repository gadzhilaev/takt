import { expect, type APIRequestContext, type Page } from "@playwright/test";
import fs from "fs";
import path from "path";

/** Prefer dedicated demo credentials; never default to the working admin board. */
const demoCreds = readDemoCredentialsFallback();

export const E2E_USER = {
  email:
    process.env.E2E_EMAIL ||
    process.env.DEMO_USER_EMAIL ||
    demoCreds.email ||
    "demo@example.com",
  password:
    process.env.E2E_PASSWORD ||
    process.env.DEMO_USER_PASSWORD ||
    demoCreds.password ||
    "ChangeMeDemo123!",
};

export const E2E_PROJECT_NAME = "[E2E] Playwright";

function readDemoCredentialsFallback(): { email: string | null; password: string | null } {
  try {
    const p = path.join(
      process.env.HOME || "",
      "Documents/private/takt/correspondence/demo-credentials.md"
    );
    const text = fs.readFileSync(p, "utf8");
    const email = text.match(/Email:\s*`([^`]+)`/)?.[1] || null;
    const password = text.match(/Password:\s*`([^`]+)`/)?.[1] || null;
    return { email, password };
  } catch {
    return { email: null, password: null };
  }
}

export async function loginUi(page: Page) {
  await page.goto("/login");
  await page.locator("#login-email").fill(E2E_USER.email);
  await page.locator("#login-password").fill(E2E_USER.password);
  await page.getByRole("button", { name: /войти/i }).click();
  await expect(page).toHaveURL(/\/projects/, { timeout: 15_000 });
}

function csrfFromLogin(login: { headersArray: () => { name: string; value: string }[] }) {
  const setCookies = login.headersArray().filter((h) => h.name.toLowerCase() === "set-cookie");
  const csrf = setCookies
    .map((h) => h.value.split(";")[0])
    .find((c) => c.startsWith("csrf_token="))
    ?.split("=")[1];
  if (!csrf) throw new Error("csrf_token missing");
  return csrf;
}

async function authHeaders(request: APIRequestContext): Promise<{ "X-CSRF-Token": string }> {
  const me = await request.get("/api/v1/auth/me");
  if (me.ok()) {
    const cookies = await request.storageState();
    const csrf = cookies.cookies.find((c) => c.name === "csrf_token")?.value;
    expect(csrf).toBeTruthy();
    return { "X-CSRF-Token": csrf! };
  }
  const login = await request.post("/api/v1/auth/login", {
    data: { email: E2E_USER.email, password: E2E_USER.password },
  });
  expect(login.ok()).toBeTruthy();
  return { "X-CSRF-Token": csrfFromLogin(login) };
}

/**
 * Isolated E2E project under the demo user (is_demo).
 * Never creates tasks in «Общее» or other working boards.
 */
export async function ensureE2EProject(request: APIRequestContext): Promise<{
  projectId: string;
  headers: { "X-CSRF-Token": string };
}> {
  const headers = await authHeaders(request);

  const projectsRes = await request.get("/api/v1/projects");
  expect(projectsRes.ok()).toBeTruthy();
  const items = (await projectsRes.json()).items as { id: string; name: string; is_demo?: boolean }[];
  const existing = items.find((p) => p.name === E2E_PROJECT_NAME);
  if (existing) return { projectId: existing.id, headers };

  const created = await request.post("/api/v1/projects", {
    headers,
    data: {
      name: E2E_PROJECT_NAME,
      description: "Isolated Playwright project [demo-workspace]",
      color: "#315F72",
    },
  });
  expect(created.ok()).toBeTruthy();
  const projectId = (await created.json()).project.id as string;

  // Mark as demo via direct SQL is done by setup script for archived board;
  // for newly created E2E boards, soft-archive visibility is membership-only under demo user.
  return { projectId, headers };
}

export async function cleanupTaskIds(
  request: APIRequestContext,
  headers: { "X-CSRF-Token": string },
  ids: string[]
) {
  for (const id of ids) {
    await request.delete(`/api/v1/tasks/${id}`, { headers }).catch(() => null);
  }
}

import { expect, test, type Page } from "@playwright/test";
import path from "path";
import fs from "fs";

const ADMIN = {
  email: process.env.E2E_EMAIL || "admin@example.com",
  password: process.env.E2E_PASSWORD || "ChangeMeAdmin123!",
};

const OUT = path.join(__dirname, "../../docs/screenshots/takt-rebrand");

async function loginUi(page: Page) {
  await page.goto("/login");
  await page.waitForSelector("#login-email");
  await page.locator("#login-email").fill(ADMIN.email);
  await page.locator("#login-password").fill(ADMIN.password);
  await page.getByRole("button", { name: /войти/i }).click();
  await expect(page).toHaveURL(/\/(home|my|projects)/, { timeout: 20_000 });
}

async function setTheme(page: Page, theme: "light" | "dark") {
  await page.evaluate((t) => {
    const html = document.documentElement;
    if (t === "dark") {
      html.classList.add("dark");
      html.classList.remove("light");
    } else {
      html.classList.remove("dark");
      html.classList.add("light");
    }
    localStorage.setItem("theme", t);
  }, theme);
  await page.waitForTimeout(250);
}

test.describe("takt visual screenshots", () => {
  test("capture ≤12 brand views", async ({ page }) => {
    fs.mkdirSync(OUT, { recursive: true });
    for (const f of fs.readdirSync(OUT)) fs.unlinkSync(path.join(OUT, f));

    let n = 0;
    const shot = async (name: string) => {
      n += 1;
      await page.screenshot({
        path: path.join(OUT, `${String(n).padStart(2, "0")}-${name}.png`),
        fullPage: false,
      });
    };

    await page.setViewportSize({ width: 1280, height: 800 });
    await page.goto("/login");
    await page.waitForSelector("text=Вход в Takt");
    await setTheme(page, "light");
    await shot("login-light-desktop");

    await loginUi(page);
    await setTheme(page, "light");
    await page.goto("/home");
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(400);
    await shot("home-light-desktop");

    await page.goto("/projects");
    await page.waitForLoadState("networkidle");
    // Prefer project cards on the page (sidebar links can be off-screen / hidden on narrow).
    const projectCard = page.locator('main a[href^="/projects/"]').first();
    await expect(projectCard).toBeVisible({ timeout: 10_000 });
    const projectHref = await projectCard.getAttribute("href");
    await projectCard.click();
    await page.waitForURL(/\/projects\/.+/);
    await page.waitForTimeout(700);
    await shot("kanban-light-desktop");
    const projectPath = projectHref || page.url().replace(/^https?:\/\/[^/]+/, "");

    await page.goto("/list");
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(400);
    await shot("list-light-desktop");

    await page.goto("/report");
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(700);
    await shot("report-light-desktop");

    await setTheme(page, "dark");
    await page.goto("/home");
    await page.waitForTimeout(500);
    await shot("home-dark-desktop");

    await page.goto(projectPath);
    await page.waitForTimeout(700);
    await shot("kanban-dark-desktop");

    await page.setViewportSize({ width: 390, height: 844 });
    await setTheme(page, "light");
    await page.goto("/home");
    await page.waitForTimeout(500);
    await shot("home-light-mobile");

    await page.goto(projectPath);
    await page.waitForTimeout(700);
    await shot("kanban-light-mobile");

    await page.goto("/my");
    await page.waitForTimeout(500);
    await shot("my-light-mobile");

    await setTheme(page, "dark");
    await page.goto("/login");
    await page.waitForSelector("text=Вход в Takt");
    await page.waitForTimeout(300);
    await shot("login-dark-mobile");

    // still authenticated cookies; open report dark mobile
    await page.goto("/report");
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(700);
    await shot("report-dark-mobile");

    expect(n).toBeLessThanOrEqual(12);
    expect(n).toBe(12);
  });
});

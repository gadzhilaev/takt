import { expect, test, type Page } from "@playwright/test";
import path from "path";
import fs from "fs";

import { E2E_USER } from "./helpers";

const ADMIN = {
  email: E2E_USER.email,
  password: E2E_USER.password,
};

const OUT = path.join(__dirname, "../../docs/screenshots/takt-rebrand");

async function loginUi(page: Page) {
  await page.goto("/login");
  await page.waitForSelector("#login-email");
  await page.locator("#login-email").fill(ADMIN.email);
  await page.locator("#login-password").fill(ADMIN.password);
  await page.getByRole("button", { name: /войти/i }).click();
  await expect(page).toHaveURL(/\/app\/projects/, { timeout: 20_000 });
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
  test("capture brand views for kanban-first UI", async ({ page }) => {
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
    await page.waitForSelector('h1:text-is("Вход")');
    await setTheme(page, "light");
    await shot("login-light-desktop");

    await loginUi(page);
    await expect(page).toHaveURL(/projects\/[a-f0-9-]+/, { timeout: 15_000 });
    const projectPath = page.url().replace(/^https?:\/\/[^/]+/, "");
    await setTheme(page, "light");
    await page.waitForTimeout(500);
    await shot("kanban-light-desktop");

    await page.context().clearCookies();
    await page.goto("/register");
    await page.waitForSelector('h1:text-is("Регистрация")');
    await shot("register-light-desktop");

    await loginUi(page);
    await page.goto(projectPath);
    await page.waitForTimeout(500);
    await setTheme(page, "dark");
    await page.waitForTimeout(400);
    await shot("kanban-dark-desktop");

    await page.setViewportSize({ width: 390, height: 844 });
    await setTheme(page, "light");
    await page.goto(projectPath);
    await page.waitForTimeout(600);
    await shot("kanban-light-mobile");

    await page.context().clearCookies();
    await page.goto("/login");
    await page.waitForSelector('h1:text-is("Вход")');
    await setTheme(page, "dark");
    await page.waitForTimeout(300);
    await shot("login-dark-mobile");

    await loginUi(page);
    await page.setViewportSize({ width: 390, height: 844 });
    await setTheme(page, "dark");
    await page.goto(projectPath);
    await page.waitForTimeout(500);
    await shot("kanban-dark-mobile");

    expect(n).toBeLessThanOrEqual(12);
    expect(n).toBeGreaterThanOrEqual(6);
  });
});

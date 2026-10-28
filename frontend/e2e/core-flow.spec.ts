import { expect, test, type Page } from "@playwright/test";

const ADMIN = {
  email: process.env.E2E_EMAIL || "admin@example.com",
  password: process.env.E2E_PASSWORD || "ChangeMeAdmin123!",
};

async function loginUi(page: Page) {
  await page.goto("/login");
  await page.locator("#login-email").fill(ADMIN.email);
  await page.locator("#login-password").fill(ADMIN.password);
  await page.getByRole("button", { name: /войти/i }).click();
  await expect(page).toHaveURL(/\/(home|my|projects)/, { timeout: 15_000 });
}

test.describe("core teacher/staff flow", () => {
  test("login → create → assign → due → my → complete", async ({ page }) => {
    await loginUi(page);

    await page.getByRole("button", { name: /создать задачу/i }).first().click();
    await expect(page).toHaveURL(/projects\/.+/, { timeout: 10_000 });

    const title = `E2E поручение ${Date.now()}`;
    const addBtn = page.getByRole("button", { name: /добавить задачу/i }).first();
    await addBtn.click();
    await page.getByLabel(/новая задача/i).fill(title);
    await page.getByRole("button", { name: /^сохранить$/i }).click();
    await expect(page.getByText(title).first()).toBeVisible({ timeout: 10_000 });

    await page.getByText(title).first().click();
    await expect(page).toHaveURL(/\/tasks\//);

    await page.getByLabel(/срок/i).fill("2030-06-15");
    // wait for autosave indicator / settle
    await page.waitForTimeout(800);

    const assigneeBox = page.getByRole("group", { name: /кто выполняет/i });
    const firstAssignee = assigneeBox.locator("label").first();
    if (await firstAssignee.count()) {
      await firstAssignee.click();
      await page.waitForTimeout(600);
    }

    await page.goto("/my");
    await expect(page.getByRole("heading", { name: /мои задачи/i })).toBeVisible();
    await expect(page.getByText(title).first()).toBeVisible({ timeout: 10_000 });

    await page.getByText(title).first().click();
    const complete = page.getByRole("button", { name: /отметить выполненной/i }).first();
    await expect(complete).toBeVisible();
    await complete.click();
    await page.waitForTimeout(700);
    await expect(page.getByRole("button", { name: /отметить выполненной/i })).toHaveCount(0);
  });

  test("mobile board: one column tabs + status select moves task", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await loginUi(page);

    // Ensure projects are in the shell before create (avoids /projects without id)
    await page.getByRole("navigation", { name: /мобильная навигация/i }).getByRole("link", { name: /проекты/i }).click();
    await expect(page.getByRole("heading", { name: /проекты/i })).toBeVisible({ timeout: 10_000 });
    await page.getByRole("navigation", { name: /мобильная навигация/i }).getByRole("button", { name: /создать задачу/i }).click();
    await expect(page).toHaveURL(/projects\/.+create=1|projects\/[a-f0-9-]+/, { timeout: 15_000 });
    // Land on a concrete board
    if (!/projects\/[a-f0-9-]{8,}/.test(page.url())) {
      await page.getByRole("link").filter({ hasText: /.+/ }).first().click();
    }
    await expect(page).toHaveURL(/projects\/[a-f0-9-]+/, { timeout: 10_000 });

    await expect(page.getByRole("tablist", { name: /статусы доски/i })).toBeVisible({ timeout: 15_000 });
    await expect(page.getByRole("tab").first()).toBeVisible();

    const title = `Mobile status ${Date.now()}`;
    // ?create=1 may already open the quick-create form
    const quickInput = page.getByLabel(/новая задача/i);
    if (!(await quickInput.isVisible().catch(() => false))) {
      await page.getByRole("button", { name: /добавить задачу/i }).click();
    }
    await quickInput.fill(title);
    await page.getByRole("button", { name: /^сохранить$/i }).click();
    await expect(page.getByText(title).first()).toBeVisible({ timeout: 10_000 });

    const card = page.locator("article").filter({ has: page.getByRole("heading", { name: title }) });
    const statusSelect = card.locator("select");
    await expect(statusSelect).toBeVisible();
    const options = statusSelect.locator("option");
    expect(await options.count()).toBeGreaterThan(1);
    const current = await statusSelect.inputValue();
    let targetValue = await options.nth(1).getAttribute("value");
    let targetLabel = (await options.nth(1).textContent())?.trim() || "";
    if (targetValue === current) {
      targetValue = await options.nth(0).getAttribute("value");
      targetLabel = (await options.nth(0).textContent())?.trim() || "";
    }
    await statusSelect.selectOption(targetValue!);
    // Card leaves the current column after move
    await expect(page.getByRole("heading", { name: title })).toHaveCount(0, { timeout: 10_000 });

    await page.getByRole("tab", { name: new RegExp(targetLabel.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")) }).click();
    await expect(page.getByRole("heading", { name: title })).toBeVisible({ timeout: 10_000 });
    await expect(
      page.locator("article").filter({ has: page.getByRole("heading", { name: title }) }).locator("select")
    ).toHaveValue(targetValue!);
  });

  test("list filters persist in URL", async ({ page }) => {
    await loginUi(page);
    await page.goto("/list?search=Excel&sort=title");
    await expect(page.getByLabel(/поиск в списке/i)).toHaveValue("Excel");
    await expect(page.getByLabel(/сортировка/i)).toHaveValue("title");
    await page.getByLabel(/сортировка/i).selectOption("due");
    await expect(page).toHaveURL(/sort=due/);
  });

  test("API move persists status and patch saves due/assignees", async ({ request }) => {
    const login = await request.post("/api/v1/auth/login", {
      data: { email: ADMIN.email, password: ADMIN.password },
    });
    expect(login.ok()).toBeTruthy();
    const setCookies = login.headersArray().filter((h) => h.name.toLowerCase() === "set-cookie");
    const csrf = setCookies
      .map((h) => h.value.split(";")[0])
      .find((c) => c.startsWith("csrf_token="))
      ?.split("=")[1];
    expect(csrf).toBeTruthy();
    const headers = { "X-CSRF-Token": csrf! };

    const statusesRes = await request.get("/api/v1/settings/statuses");
    expect(statusesRes.ok()).toBeTruthy();
    const statuses = (await statusesRes.json()).items as { id: string; is_done: boolean; name: string }[];
    const open = statuses.find((s) => !s.is_done)!;
    const done = statuses.find((s) => s.is_done)!;
    expect(open && done).toBeTruthy();

    const usersRes = await request.get("/api/v1/users");
    const users = (await usersRes.json()).items as { id: string }[];
    expect(users.length).toBeGreaterThan(0);

    const created = await request.post("/api/v1/tasks", {
      headers,
      data: { title: `API move ${Date.now()}`, status_id: open.id, priority: "medium" },
    });
    expect(created.ok()).toBeTruthy();
    const task = (await created.json()).task as { id: string; status_id: string };

    const patched = await request.patch(`/api/v1/tasks/${task.id}`, {
      headers,
      data: {
        due_date: "2031-01-10T12:00:00.000Z",
        assignee_ids: [users[0].id],
      },
    });
    expect(patched.ok()).toBeTruthy();
    const afterPatch = (await patched.json()).task;
    expect(afterPatch.due_date).toBeTruthy();
    expect(afterPatch.assignees?.length || afterPatch.assignee_ids?.length).toBeTruthy();

    const moved = await request.post(`/api/v1/tasks/${task.id}/move`, {
      headers,
      data: { status_id: done.id, position: 2048 },
    });
    expect(moved.ok()).toBeTruthy();
    const movedTask = (await moved.json()).task;
    expect(movedTask.status_id).toBe(done.id);
    expect(movedTask.status?.id || movedTask.status_id).toBeTruthy();
    expect(movedTask.closed_at).toBeTruthy();

    const fetched = await request.get(`/api/v1/tasks/${task.id}`);
    const fresh = (await fetched.json()).task;
    expect(fresh.status_id).toBe(done.id);
    expect(fresh.closed_at).toBeTruthy();
  });
});

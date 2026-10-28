import { expect, test, type Page } from "@playwright/test";
import { cleanupTaskIds, ensureE2EProject, loginUi } from "./helpers";

test.describe("simple kanban flow", () => {
  test("login → E2E project → create task → overlay → persist", async ({ page, request }) => {
    const { projectId, headers } = await ensureE2EProject(request);
    const createdIds: string[] = [];

    await loginUi(page);
    await page.goto(`/projects/${projectId}`);
    await expect(page).toHaveURL(new RegExp(`projects/${projectId}`), { timeout: 15_000 });

    const title = `E2E задача ${Date.now()}`;
    await page.getByRole("button", { name: /^добавить$/i }).first().click();
    await page.getByLabel(/^название$/i).fill(title);
    await page.getByRole("button", { name: /^создать$/i }).click();
    await expect(page.getByRole("heading", { name: title })).toBeVisible({ timeout: 10_000 });

    await page.getByRole("heading", { name: title }).click();
    await expect(page).toHaveURL(/[?&]task=/);
    await expect(page.getByRole("dialog", { name: /задача/i })).toBeVisible();

    await page.getByLabel(/^описание$/i).fill("Краткое описание");
    await page.getByLabel(/^описание$/i).blur();
    await page.waitForTimeout(400);

    await page.keyboard.press("Escape");
    await expect(page).not.toHaveURL(/[?&]task=/);
    await expect(page.getByRole("heading", { name: title })).toBeVisible({ timeout: 10_000 });

    await page.reload();
    await expect(page.getByRole("heading", { name: title })).toBeVisible({ timeout: 10_000 });

    const tasks = await request.get(`/api/v1/tasks?project_id=${projectId}&page_size=100`);
    const items = (await tasks.json()).items as { id: string; title: string }[];
    for (const t of items.filter((x) => x.title === title)) createdIds.push(t.id);
    await cleanupTaskIds(request, headers, createdIds);
  });

  test("mobile board: one column + change column via select", async ({ page, request }) => {
    const { projectId, headers } = await ensureE2EProject(request);
    await page.setViewportSize({ width: 390, height: 844 });
    await loginUi(page);
    await page.goto(`/projects/${projectId}`);
    await expect(page.getByRole("tablist", { name: /столбцы/i })).toBeVisible({ timeout: 15_000 });

    const title = `Mobile ${Date.now()}`;
    await page.getByRole("button", { name: /^добавить$/i }).click();
    await page.getByLabel(/^название$/i).fill(title);
    await page.getByRole("button", { name: /^создать$/i }).click();
    await expect(page.getByRole("heading", { name: title })).toBeVisible({ timeout: 10_000 });

    const card = page.locator("article").filter({ has: page.getByRole("heading", { name: title }) });
    await card.getByRole("combobox").click();
    const options = page.getByRole("option");
    expect(await options.count()).toBeGreaterThan(1);
    const targetLabel = (await options.nth(1).textContent())?.trim() || "";
    await options.nth(1).click();
    await expect(page.getByRole("heading", { name: title })).toHaveCount(0, { timeout: 10_000 });

    await page.getByRole("tab", { name: new RegExp(targetLabel.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")) }).click();
    await expect(page.getByRole("heading", { name: title })).toBeVisible({ timeout: 10_000 });

    const tasks = await request.get(`/api/v1/tasks?project_id=${projectId}&page_size=100`);
    const items = (await tasks.json()).items as { id: string; title: string }[];
    await cleanupTaskIds(
      request,
      headers,
      items.filter((x) => x.title === title).map((x) => x.id)
    );
  });

  test("register page is available", async ({ page }) => {
    await page.goto("/register");
    await expect(page.getByRole("heading", { name: /регистрация/i })).toBeVisible();
    await expect(page.getByLabel(/^имя$/i)).toBeVisible();
  });

  test("API move persists column and assignee in E2E project", async ({ request }) => {
    const { projectId, headers } = await ensureE2EProject(request);

    const statusesRes = await request.get(`/api/v1/settings/statuses?project_id=${projectId}`);
    expect(statusesRes.ok()).toBeTruthy();
    const statuses = (await statusesRes.json()).items as { id: string; is_done: boolean }[];
    const open = statuses.find((s) => !s.is_done)!;
    const done = statuses.find((s) => s.is_done)!;

    const projectRes = await request.get(`/api/v1/projects/${projectId}`);
    expect(projectRes.ok()).toBeTruthy();
    const members = (await projectRes.json()).project.members as { user_id: string }[];
    const assigneeIds = members.slice(0, 2).map((m) => m.user_id);

    const created = await request.post("/api/v1/tasks", {
      headers,
      data: {
        title: `API move ${Date.now()}`,
        status_id: open.id,
        project_id: projectId,
        assignee_ids: assigneeIds,
      },
    });
    expect(created.ok()).toBeTruthy();
    const task = (await created.json()).task as { id: string; assignees: unknown[] };
    expect((task.assignees || []).length).toBeGreaterThanOrEqual(1);

    const moved = await request.post(`/api/v1/tasks/${task.id}/move`, {
      headers,
      data: { status_id: done.id, position: 2048 },
    });
    expect(moved.ok()).toBeTruthy();
    expect((await moved.json()).task.status_id).toBe(done.id);

    // Move to first position in done
    const first = await request.post(`/api/v1/tasks/${task.id}/move`, {
      headers,
      data: { status_id: done.id, position: -512 },
    });
    expect(first.ok()).toBeTruthy();
    expect((await first.json()).task.position).toBe(-512);

    await cleanupTaskIds(request, headers, [task.id]);
  });

  test("DnD first position in done column via API order", async ({ request }) => {
    const { projectId, headers } = await ensureE2EProject(request);
    const statuses = (
      await (await request.get(`/api/v1/settings/statuses?project_id=${projectId}`)).json()
    ).items as { id: string; is_done: boolean }[];
    const open = statuses.find((s) => !s.is_done)!;
    const done = statuses.find((s) => s.is_done)!;

    const a = await request.post("/api/v1/tasks", {
      headers,
      data: { title: `DnD A ${Date.now()}`, status_id: done.id, project_id: projectId },
    });
    const b = await request.post("/api/v1/tasks", {
      headers,
      data: { title: `DnD B ${Date.now()}`, status_id: open.id, project_id: projectId },
    });
    const taskA = (await a.json()).task as { id: string; position: number };
    const taskB = (await b.json()).task as { id: string };

    const pos = taskA.position === 0 ? -1024 : taskA.position / 2;
    const moved = await request.post(`/api/v1/tasks/${taskB.id}/move`, {
      headers,
      data: { status_id: done.id, position: pos },
    });
    expect(moved.ok()).toBeTruthy();
    const list = (
      await (await request.get(`/api/v1/tasks?project_id=${projectId}&page_size=100`)).json()
    ).items as { id: string; status_id: string; position: number }[];
    const doneTasks = list
      .filter((t) => t.status_id === done.id)
      .sort((x, y) => x.position - y.position);
    expect(doneTasks[0].id).toBe(taskB.id);

    await cleanupTaskIds(request, headers, [taskA.id, taskB.id]);
  });
});

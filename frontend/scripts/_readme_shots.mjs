import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const { chromium } = require('@playwright/test');
import fs from 'fs';
import path from 'path';

const BASE = process.env.BASE_URL || 'http://127.0.0.1:3000';
const EMAIL = process.env.DEMO_EMAIL;
const PASS = process.env.DEMO_PASS;
const OUT = process.env.OUT_DIR;
const PROJECT = 'Запуск продукта';

async function main() {
  const browser = await chromium.launch({ headless: true, channel: 'chrome' });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 2,
    locale: 'ru-RU',
  });
  const page = await context.newPage();

  await page.goto(BASE + '/', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1000);
  await page.screenshot({ path: path.join(OUT, 'web-landing.png'), fullPage: false });
  console.log('landing ok');

  await page.goto(BASE + '/login', { waitUntil: 'networkidle' });
  await page.locator('#login-email, input[name="email"]').first().fill(EMAIL);
  await page.locator('#login-password, input[name="password"]').first().fill(PASS);
  await page.getByRole('button', { name: 'Войти' }).click();
  await page.waitForURL(/\/app\//, { timeout: 25000 });
  await page.waitForTimeout(1200);
  console.log('logged in', page.url());

  // Dismiss push / soft prompts if any
  const dismiss = page.getByRole('button', { name: /закрыть|позже|не сейчас|нет,? спасибо/i });
  if (await dismiss.count()) {
    try { await dismiss.first().click({ timeout: 2000 }); } catch {}
  }
  const overlayClose = page.locator('button[aria-label="Закрыть"]');
  if (await overlayClose.count()) {
    try { await overlayClose.first().click({ timeout: 2000 }); } catch {}
  }
  await page.waitForTimeout(400);

  // Prefer deep link to project board (avoids sidebar intercepts)
  const projects = await page.evaluate(async () => {
    const r = await fetch('/api/v1/projects', { credentials: 'include' });
    return r.json();
  });
  const items = projects.items || projects.projects || [];
  const hit = items.find((p) => p.name === PROJECT) || items[0];
  if (!hit) throw new Error('No projects for demo user');
  await page.goto(`${BASE}/app/projects/${hit.id}`, { waitUntil: 'networkidle' });
  await page.waitForTimeout(1800);
  const boardTab = page.getByText('Доска', { exact: true });
  if (await boardTab.count()) {
    try { await boardTab.first().click({ timeout: 2000 }); } catch {}
  }
  await page.evaluate(async () => {
    localStorage.setItem('takt_push_prompt_never', '1');
    try {
      await fetch('/api/v1/notifications/read-all', { method: 'POST', credentials: 'include' });
    } catch {}
  });
  const notNow = page.getByRole('button', { name: /не сейчас/i });
  if (await notNow.count()) {
    try { await notNow.first().click({ timeout: 1500 }); } catch {}
  }
  await page.reload({ waitUntil: 'networkidle' });
  await page.waitForTimeout(1400);
  await page.evaluate(() => {
    document.querySelectorAll('body *').forEach((el) => {
      if (!(el instanceof HTMLElement)) return;
      const t = el.innerText || '';
      if (t.includes('назначил') && t.includes('Проект') && el.className.includes('fixed')) {
        el.style.display = 'none';
      }
    });
  });
  await page.screenshot({ path: path.join(OUT, 'web-kanban-light.png'), fullPage: false });
  console.log('light ok');

  await page.evaluate(() => {
    localStorage.setItem('theme', 'dark');
    localStorage.setItem('takt_push_prompt_never', '1');
    document.documentElement.classList.add('dark');
  });
  await page.reload({ waitUntil: 'networkidle' });
  await page.waitForTimeout(1400);
  await page.evaluate(() => {
    document.querySelectorAll('body *').forEach((el) => {
      if (!(el instanceof HTMLElement)) return;
      const t = el.innerText || '';
      if (t.includes('назначил') && t.includes('Проект') && el.className.includes('fixed')) {
        el.style.display = 'none';
      }
    });
  });
  await page.screenshot({ path: path.join(OUT, 'web-kanban-dark.png'), fullPage: false });
  console.log('dark ok');

  await browser.close();
  console.log('files', fs.readdirSync(OUT).filter(f => f.startsWith('web-')));
}
main().catch((e) => { console.error(e); process.exit(1); });

#!/usr/bin/env node
/**
 * Sync Lucide SVGs into shared/icons with Takt stroke settings.
 * Requires: npm install --no-save lucide-static
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const srcDir = path.join(root, "node_modules/lucide-static/icons");
const dstDir = path.join(root, "shared/icons");

const MAP = {
  home: "house",
  "my-tasks": "list-checks",
  profile: "user",
  back: "arrow-left",
  close: "x",
  more: "ellipsis",
  add: "plus",
  edit: "pencil",
  delete: "trash-2",
  check: "check",
  "chevron-down": "chevron-down",
  "chevron-right": "chevron-right",
  "chevron-left": "chevron-left",
  notifications: "bell",
  search: "search",
  settings: "settings",
  lock: "lock",
  logout: "log-out",
  invite: "user-plus",
  theme: "contrast",
  mail: "mail",
  eye: "eye",
  "eye-off": "eye-off",
  menu: "menu",
  camera: "camera",
  copy: "copy",
  monitor: "monitor",
  moon: "moon",
  sun: "sun",
  alert: "circle-alert",
  message: "message-circle",
  status: "arrow-left-right",
  inbox: "inbox",
  circle: "circle",
  "circle-check": "circle-check",
  assignment: "clipboard-list",
  forum: "messages-square",
};

if (!fs.existsSync(srcDir)) {
  console.error("Install lucide-static first: npm install --no-save lucide-static");
  process.exit(1);
}

fs.mkdirSync(dstDir, { recursive: true });
const manifest = { strokeWidth: 1.75, viewBox: "0 0 24 24", icons: {} };

for (const [semantic, lucideName] of Object.entries(MAP)) {
  const src = path.join(srcDir, `${lucideName}.svg`);
  if (!fs.existsSync(src)) throw new Error(`Missing Lucide icon: ${lucideName}`);
  let text = fs.readFileSync(src, "utf8");
  text = text.replace(/stroke-width="[^"]+"/g, 'stroke-width="1.75"');
  if (!text.includes("stroke-linecap=")) {
    text = text.replace("<svg ", '<svg stroke-linecap="round" stroke-linejoin="round" ');
  }
  fs.writeFileSync(path.join(dstDir, `${semantic}.svg`), text);
  manifest.icons[semantic] = { file: `${semantic}.svg`, lucide: lucideName };
}

fs.writeFileSync(path.join(dstDir, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`Synced ${Object.keys(MAP).length} icons → shared/icons`);

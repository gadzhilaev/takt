import { describe, expect, it } from "vitest";
import {
  COLUMN_COLOR_PALETTE,
  columnAccentBar,
  resolveColumnColors,
  resolveColumnPreset,
  suggestUnusedColumnColor,
} from "./column-colors";

describe("column-colors", () => {
  it("maps standard accents to solid surfaces", () => {
    const todo = resolveColumnColors("#607FA4");
    expect(todo.bg).toBe("#D2DDEB");
    expect(todo.value).toBe("#607FA4");
    expect(columnAccentBar("#398A62").backgroundColor).toBe("#398A62");
  });

  it("aliases previous standard accents to current presets", () => {
    expect(resolveColumnColors("#7892B2").bg).toBe("#D2DDEB");
    expect(resolveColumnPreset("#4b8caf")?.id).toBe("doing");
  });

  it("is case-insensitive for presets", () => {
    expect(resolveColumnPreset("#347fa4")?.id).toBe("doing");
  });

  it("derives opaque mixes for custom colors", () => {
    const custom = resolveColumnColors("#336699");
    expect(custom.bg).toContain("color-mix");
    expect(custom.bgDark).toContain("color-mix");
  });

  it("exposes four standard board colors in the palette", () => {
    const ids = COLUMN_COLOR_PALETTE.map((c) => c.id);
    expect(ids).toEqual(expect.arrayContaining(["todo", "doing", "review", "done"]));
  });

  it("suggests a color not already used on the board", () => {
    const used = COLUMN_COLOR_PALETTE.map((c) => c.value);
    const next = suggestUnusedColumnColor(used);
    expect(used.map((c) => c.toLowerCase())).not.toContain(next.toLowerCase());
    expect(next).toMatch(/^#[0-9A-Fa-f]{6}$/);
  });
});

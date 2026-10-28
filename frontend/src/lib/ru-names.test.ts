import { describe, expect, it } from "vitest";

// Mirror of backend midPosition edge case for first slot
function midPosition(before?: number, after?: number) {
  if (before == null && after == null) return 1024;
  if (before == null) {
    const a = after as number;
    return a === 0 ? -1024 : a / 2;
  }
  if (after == null) return before + 1024;
  if (before === after) return before - 1024;
  return (before + after) / 2;
}

describe("midPosition for DnD head insert", () => {
  it("inserts before position 0 without colliding", () => {
    expect(midPosition(undefined, 0)).toBe(-1024);
    expect(midPosition(undefined, 1024)).toBe(512);
  });
});

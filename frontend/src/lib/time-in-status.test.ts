import { describe, expect, it } from "vitest";
import { formatTimeInStatus } from "./time-in-status";

describe("formatTimeInStatus", () => {
  const base = Date.parse("2026-11-03T12:00:00.000Z");

  it("formats minutes hours days weeks", () => {
    expect(formatTimeInStatus(new Date(base - 30_000).toISOString(), base)).toBe("сейчас");
    expect(formatTimeInStatus(new Date(base - 5 * 60_000).toISOString(), base)).toBe("5 мин.");
    expect(formatTimeInStatus(new Date(base - 3 * 3600_000).toISOString(), base)).toBe("3 ч.");
    expect(formatTimeInStatus(new Date(base - 2 * 86400_000).toISOString(), base)).toBe("2 д.");
    expect(formatTimeInStatus(new Date(base - 21 * 7 * 86400_000).toISOString(), base)).toBe("21 нед.");
    expect(
      formatTimeInStatus(new Date(base - (16 * 7 + 4) * 86400_000).toISOString(), base)
    ).toBe("16 нед., 4 д.");
  });

  it("returns null for bad input", () => {
    expect(formatTimeInStatus(null)).toBeNull();
    expect(formatTimeInStatus("nope")).toBeNull();
  });
});

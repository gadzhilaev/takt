import { describe, expect, it } from "vitest";
import { formatCreatedAt } from "./format-created-at";

describe("formatCreatedAt", () => {
  const now = new Date(2026, 10, 3, 17, 30); // local Nov 3 2026

  it("formats today yesterday and absolute", () => {
    expect(formatCreatedAt(new Date(2026, 10, 3, 18, 0).toISOString(), now)).toBe("сегодня в 18:00");
    expect(formatCreatedAt(new Date(2026, 10, 2, 18, 0).toISOString(), now)).toBe("вчера в 18:00");
    expect(formatCreatedAt(new Date(2026, 10, 18, 18, 0).toISOString(), now)).toBe("18.11.2026 в 18:00");
  });

  it("returns null for bad input", () => {
    expect(formatCreatedAt(null)).toBeNull();
    expect(formatCreatedAt("nope")).toBeNull();
  });
});

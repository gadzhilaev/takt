import { describe, expect, it } from "vitest";
import { daysLabel, formatHours, missedLabel, participationLabel, periodLabel } from "./digest";

describe("digest helpers", () => {
  it("formatHours", () => {
    expect(formatHours(0.4)).toBe("< 1 ч.");
    expect(formatHours(5.4)).toBe("5 ч.");
    expect(formatHours(48)).toBe("2 д.");
    expect(formatHours(30)).toBe("1 д. 6 ч.");
  });
  it("daysLabel", () => {
    expect(daysLabel(0)).toBe("меньше дня");
    expect([1, 2, 5, 11, 21, 23].map(daysLabel)).toEqual([
      "1 день",
      "2 дня",
      "5 дней",
      "11 дней",
      "21 день",
      "23 дня",
    ]);
  });
  it("labels", () => {
    expect(participationLabel(null)).toBe("—");
    expect(participationLabel(75)).toBe("75%");
    expect(periodLabel({ kind: "week", start: "2026-11-11", end: "2026-11-17", timezone: "" })).toBe(
      "11.11 — 17.11"
    );
    expect(periodLabel({ kind: "day", start: "2026-11-17", end: "2026-11-17", timezone: "" })).toBe(
      "17.11"
    );
    expect(missedLabel({ missed: 1, total: 5 })).toBe("без ответа: 1 из 5");
  });
});

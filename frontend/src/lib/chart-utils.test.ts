import { describe, expect, it } from "vitest";
import { formatAvgDays, formatOnTimePct, padClosedByDay, yAxisMax } from "./chart-utils";

describe("padClosedByDay", () => {
  it("returns empty for empty input", () => {
    expect(padClosedByDay([])).toEqual([]);
  });

  it("pads a single point to 3 slots", () => {
    const out = padClosedByDay([{ day: "10-28", count: 3 }]);
    expect(out).toHaveLength(3);
    expect(out.filter((d) => d.count > 0)).toHaveLength(1);
    expect(out.find((d) => d.day === "10-28")?.count).toBe(3);
  });

  it("keeps 3+ points unchanged length", () => {
    const data = [
      { day: "10-26", count: 1 },
      { day: "10-27", count: 2 },
      { day: "10-28", count: 3 },
    ];
    expect(padClosedByDay(data)).toHaveLength(3);
  });
});

describe("yAxisMax", () => {
  it("never returns below 1", () => {
    expect(yAxisMax([{ count: 0 }])).toBe(1);
    expect(yAxisMax([{ count: 5 }])).toBe(5);
  });
});

describe("formatAvgDays", () => {
  it("shows dash when nothing closed", () => {
    expect(formatAvgDays(0, 0)).toBe("—");
    expect(formatAvgDays(null, 0)).toBe("—");
  });

  it("shows < 1 for tiny averages", () => {
    expect(formatAvgDays(0.01, 3)).toBe("< 1");
  });

  it("rounds normal values", () => {
    expect(formatAvgDays(2.36, 3)).toBe("2.4");
  });
});

describe("formatOnTimePct", () => {
  it("formats null as dash", () => {
    expect(formatOnTimePct(null)).toBe("—");
  });

  it("formats numbers with percent", () => {
    expect(formatOnTimePct(50)).toBe("50%");
  });
});

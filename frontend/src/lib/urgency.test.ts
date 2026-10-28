import { describe, expect, it } from "vitest";
import { urgencyColor, urgencyFromPriority, urgencyLabel } from "./urgency";

describe("urgency", () => {
  it("maps priority to three urgency levels", () => {
    expect(urgencyFromPriority("urgent")).toBe("urgent");
    expect(urgencyFromPriority("high")).toBe("high");
    expect(urgencyFromPriority("medium")).toBe("medium");
    expect(urgencyFromPriority("low")).toBe("medium");
  });

  it("uses the brand palette colors", () => {
    expect(urgencyColor("urgent")).toBe("#C2413B");
    expect(urgencyColor("high")).toBe("#B7791F");
    expect(urgencyColor("medium")).toBe("#315F72");
    expect(urgencyLabel("urgent")).toBe("Срочно");
  });
});

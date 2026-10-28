import { describe, expect, it } from "vitest";
import {
  urgencyColor,
  urgencyFromPriority,
  urgencyLabel,
  urgencySoft,
} from "./urgency";

describe("urgency", () => {
  it("maps priority to three urgency levels", () => {
    expect(urgencyFromPriority("urgent")).toBe("urgent");
    expect(urgencyFromPriority("high")).toBe("high");
    expect(urgencyFromPriority("medium")).toBe("medium");
    expect(urgencyFromPriority("low")).toBe("medium");
  });

  it("uses the distinct urgency palette", () => {
    expect(urgencyColor("urgent")).toBe("#C63F3F");
    expect(urgencySoft("urgent")).toBe("#FCE8E8");
    expect(urgencyColor("high")).toBe("#C47A12");
    expect(urgencySoft("high")).toBe("#FFF0D4");
    expect(urgencyColor("medium")).toBe("#326E8B");
    expect(urgencySoft("medium")).toBe("#E4F0F6");
    expect(urgencyLabel("urgent")).toBe("Срочно");
  });
});

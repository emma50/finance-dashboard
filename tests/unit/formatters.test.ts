import { describe, expect, it } from "vitest";

import { formatMinorCurrency } from "@/lib/formatters/currency";

describe("formatMinorCurrency", () => {
  it("formats NGN minor units as naira", () => {
    expect(formatMinorCurrency(12_505_050, "NGN")).toContain("125,050.50");
  });
});

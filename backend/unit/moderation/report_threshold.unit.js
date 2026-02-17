describe("MODERATION / REPORT THRESHOLD", () => {
  /**
   * Rules:
   * - Each report has weight
   * - Action triggered when total weight >= threshold
   * - Duplicate reports from same reporter count once
   */

  function shouldTriggerAction({
    reports,
    threshold,
  }) {
    const unique = new Map();
    for (const r of reports) {
      if (!unique.has(r.reporter)) {
        unique.set(r.reporter, r.weight);
      }
    }
    const totalWeight = Array.from(unique.values()).reduce((a, b) => a + b, 0);
    return totalWeight >= threshold;
  }

  it("should not trigger when below threshold", () => {
    const result = shouldTriggerAction({
      threshold: 5,
      reports: [
        { reporter: "u1", weight: 1 },
        { reporter: "u2", weight: 2 },
      ],
    });
    expect(result).toBe(false);
  });

  it("should trigger when reaching threshold", () => {
    const result = shouldTriggerAction({
      threshold: 5,
      reports: [
        { reporter: "u1", weight: 2 },
        { reporter: "u2", weight: 3 },
      ],
    });
    expect(result).toBe(true);
  });

  it("should ignore duplicate reports from same reporter", () => {
    const result = shouldTriggerAction({
      threshold: 3,
      reports: [
        { reporter: "u1", weight: 2 },
        { reporter: "u1", weight: 2 },
      ],
    });
    expect(result).toBe(false);
  });

  it("should count only first report per reporter", () => {
    const result = shouldTriggerAction({
      threshold: 2,
      reports: [
        { reporter: "u1", weight: 2 },
        { reporter: "u1", weight: 5 },
      ],
    });
    expect(result).toBe(true);
  });
});

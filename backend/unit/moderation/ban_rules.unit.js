describe("MODERATION / BAN RULES", () => {
  /**
   * Rules:
   * - Temporary ban for medium violations
   * - Permanent ban for severe violations
   * - Escalation on repeated offenses
   */

  function decideBan({ severity, strikes }) {
    if (severity === "severe") {
      return { type: "permanent", durationDays: null };
    }
    if (severity === "medium" && strikes >= 3) {
      return { type: "temporary", durationDays: 30 };
    }
    if (severity === "medium") {
      return { type: "temporary", durationDays: 7 };
    }
    if (severity === "low" && strikes >= 5) {
      return { type: "temporary", durationDays: 3 };
    }
    return { type: "none", durationDays: 0 };
  }

  it("should permanently ban for severe violation", () => {
    const result = decideBan({ severity: "severe", strikes: 1 });
    expect(result.type).toBe("permanent");
  });

  it("should temporarily ban medium violation", () => {
    const result = decideBan({ severity: "medium", strikes: 1 });
    expect(result.type).toBe("temporary");
    expect(result.durationDays).toBe(7);
  });

  it("should escalate medium violations after multiple strikes", () => {
    const result = decideBan({ severity: "medium", strikes: 3 });
    expect(result.durationDays).toBe(30);
  });

  it("should not ban low severity first offenses", () => {
    const result = decideBan({ severity: "low", strikes: 1 });
    expect(result.type).toBe("none");
  });

  it("should ban low severity after many strikes", () => {
    const result = decideBan({ severity: "low", strikes: 5 });
    expect(result.type).toBe("temporary");
    expect(result.durationDays).toBe(3);
  });
});

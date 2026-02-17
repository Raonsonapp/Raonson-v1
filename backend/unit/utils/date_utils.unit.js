describe("UTILS / DATE", () => {
  function isExpired(date, ttlMs) {
    return Date.now() - new Date(date).getTime() > ttlMs;
  }

  function daysBetween(a, b) {
    const d1 = new Date(a).setHours(0, 0, 0, 0);
    const d2 = new Date(b).setHours(0, 0, 0, 0);
    return Math.abs((d2 - d1) / (1000 * 60 * 60 * 24));
  }

  it("should detect expired date", () => {
    const old = Date.now() - 10000;
    expect(isExpired(old, 5000)).toBe(true);
  });

  it("should detect non-expired date", () => {
    const now = Date.now();
    expect(isExpired(now, 5000)).toBe(false);
  });

  it("should calculate days between two dates", () => {
    const d1 = "2025-01-01";
    const d2 = "2025-01-05";
    expect(daysBetween(d1, d2)).toBe(4);
  });
});

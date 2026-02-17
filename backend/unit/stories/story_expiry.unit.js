describe("STORIES / EXPIRY RULES", () => {
  const STORY_LIFETIME_HOURS = 24;

  function isExpired(createdAt, now) {
    const diffMs = now - createdAt;
    const diffHours = diffMs / (1000 * 60 * 60);
    return diffHours >= STORY_LIFETIME_HOURS;
  }

  it("should expire story after 24 hours", () => {
    const createdAt = new Date("2024-01-01T00:00:00Z");
    const now = new Date("2024-01-02T01:00:00Z");

    expect(isExpired(createdAt, now)).toBe(true);
  });

  it("should keep story active before 24 hours", () => {
    const createdAt = new Date("2024-01-01T00:00:00Z");
    const now = new Date("2024-01-01T23:00:00Z");

    expect(isExpired(createdAt, now)).toBe(false);
  });
});

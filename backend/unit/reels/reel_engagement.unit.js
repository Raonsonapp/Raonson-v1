describe("REELS / ENGAGEMENT RULES", () => {
  function toggleLike(likes, userId) {
    return likes.includes(userId)
      ? likes.filter((id) => id !== userId)
      : [...likes, userId];
  }

  it("should like reel if not liked before", () => {
    const result = toggleLike(["u1"], "u2");
    expect(result).toContain("u2");
  });

  it("should unlike reel if already liked", () => {
    const result = toggleLike(["u1", "u2"], "u2");
    expect(result).not.toContain("u2");
  });

  function canCountView(lastViewAt, now) {
    const diffSec = (now - lastViewAt) / 1000;
    return diffSec >= 3;
  }

  it("should count view after 3 seconds", () => {
    const last = new Date(Date.now() - 4000);
    const now = new Date();
    expect(canCountView(last, now)).toBe(true);
  });

  it("should ignore rapid repeat views", () => {
    const last = new Date(Date.now() - 1000);
    const now = new Date();
    expect(canCountView(last, now)).toBe(false);
  });
});

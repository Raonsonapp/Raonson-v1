describe("REELS / VISIBILITY RULES", () => {
  function canViewReel({ isPrivate, ownerFollowers }, viewerId) {
    if (!isPrivate) return true;
    return ownerFollowers.includes(viewerId);
  }

  it("should allow viewing public reel", () => {
    const result = canViewReel(
      { isPrivate: false, ownerFollowers: [] },
      "userX"
    );
    expect(result).toBe(true);
  });

  it("should allow follower to view private reel", () => {
    const result = canViewReel(
      { isPrivate: true, ownerFollowers: ["userX"] },
      "userX"
    );
    expect(result).toBe(true);
  });

  it("should block non-follower from private reel", () => {
    const result = canViewReel(
      { isPrivate: true, ownerFollowers: ["userA"] },
      "userX"
    );
    expect(result).toBe(false);
  });
});

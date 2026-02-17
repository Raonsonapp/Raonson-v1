describe("STORIES / VISIBILITY RULES", () => {
  function canViewStory({ isPrivate, followers }, viewerId) {
    if (!isPrivate) return true;
    return followers.includes(viewerId);
  }

  it("should allow viewing public stories", () => {
    const result = canViewStory(
      { isPrivate: false, followers: [] },
      "userB"
    );
    expect(result).toBe(true);
  });

  it("should allow follower to view private story", () => {
    const result = canViewStory(
      { isPrivate: true, followers: ["userB"] },
      "userB"
    );
    expect(result).toBe(true);
  });

  it("should block non-follower from private story", () => {
    const result = canViewStory(
      { isPrivate: true, followers: ["userA"] },
      "userB"
    );
    expect(result).toBe(false);
  });
});

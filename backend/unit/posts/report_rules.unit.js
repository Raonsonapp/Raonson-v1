describe("POSTS / REPORT RULES", () => {
  function report(post, userId) {
    if (!post.reports.includes(userId)) {
      post.reports.push(userId);
      return true;
    }
    return false;
  }

  it("should allow reporting a post once per user", () => {
    const post = { reports: [] };

    const first = report(post, "u1");
    const second = report(post, "u1");

    expect(first).toBe(true);
    expect(second).toBe(false);
    expect(post.reports.length).toBe(1);
  });
});

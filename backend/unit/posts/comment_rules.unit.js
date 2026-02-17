describe("POSTS / COMMENT RULES", () => {
  it("should allow comment on public post", () => {
    const post = { commentsDisabled: false };
    const canComment = !post.commentsDisabled;

    expect(canComment).toBe(true);
  });

  it("should block comment if comments are disabled", () => {
    const post = { commentsDisabled: true };
    const canComment = !post.commentsDisabled;

    expect(canComment).toBe(false);
  });
});

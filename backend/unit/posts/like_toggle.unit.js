describe("POSTS / LIKE TOGGLE", () => {
  function toggleLike(post, userId) {
    if (post.likes.includes(userId)) {
      post.likes = post.likes.filter((id) => id !== userId);
      return false;
    } else {
      post.likes.push(userId);
      return true;
    }
  }

  it("should like post if not liked", () => {
    const post = { likes: [] };

    const result = toggleLike(post, "u1");

    expect(result).toBe(true);
    expect(post.likes).toContain("u1");
  });

  it("should unlike post if already liked", () => {
    const post = { likes: ["u1"] };

    const result = toggleLike(post, "u1");

    expect(result).toBe(false);
    expect(post.likes).not.toContain("u1");
  });
});

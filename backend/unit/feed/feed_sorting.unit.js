describe("FEED / SORTING", () => {
  function sortFeedByDate(posts) {
    return posts.sort(
      (a, b) => new Date(b.createdAt) - new Date(a.createdAt)
    );
  }

  it("should sort posts by newest first", () => {
    const posts = [
      { id: 1, createdAt: "2024-01-01" },
      { id: 2, createdAt: "2024-03-01" },
      { id: 3, createdAt: "2024-02-01" },
    ];

    const sorted = sortFeedByDate(posts);

    expect(sorted[0].id).toBe(2);
    expect(sorted[1].id).toBe(3);
    expect(sorted[2].id).toBe(1);
  });
});

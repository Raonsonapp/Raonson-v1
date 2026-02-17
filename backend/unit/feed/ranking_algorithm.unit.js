describe("FEED / RANKING ALGORITHM", () => {
  function scorePost(post) {
    const likeScore = post.likes * 2;
    const commentScore = post.comments * 3;
    const recencyScore = post.hoursAgo < 24 ? 10 : 0;
    return likeScore + commentScore + recencyScore;
  }

  it("should rank post with more engagement higher", () => {
    const postA = { likes: 10, comments: 2, hoursAgo: 1 };
    const postB = { likes: 2, comments: 0, hoursAgo: 1 };

    const scoreA = scorePost(postA);
    const scoreB = scorePost(postB);

    expect(scoreA).toBeGreaterThan(scoreB);
  });

  it("should boost recent posts", () => {
    const recent = { likes: 0, comments: 0, hoursAgo: 1 };
    const old = { likes: 0, comments: 0, hoursAgo: 72 };

    expect(scorePost(recent)).toBeGreaterThan(scorePost(old));
  });
});

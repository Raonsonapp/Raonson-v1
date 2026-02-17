describe("REELS / SCORING ALGORITHM", () => {
  function scoreReel({ likes, comments, shares, saves, views, ageHours }) {
    const engagement =
      likes * 3 +
      comments * 4 +
      shares * 5 +
      saves * 6 +
      views * 0.1;

    const decay = Math.max(1, ageHours);
    return engagement / decay;
  }

  it("should give higher score to high engagement reels", () => {
    const score = scoreReel({
      likes: 100,
      comments: 20,
      shares: 10,
      saves: 15,
      views: 5000,
      ageHours: 2,
    });

    expect(score).toBeGreaterThan(100);
  });

  it("should reduce score for older reels", () => {
    const fresh = scoreReel({
      likes: 50,
      comments: 10,
      shares: 5,
      saves: 5,
      views: 2000,
      ageHours: 1,
    });

    const old = scoreReel({
      likes: 50,
      comments: 10,
      shares: 5,
      saves: 5,
      views: 2000,
      ageHours: 24,
    });

    expect(fresh).toBeGreaterThan(old);
  });
});

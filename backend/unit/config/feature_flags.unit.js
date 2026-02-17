describe("CONFIG / FEATURE FLAGS", () => {
  function resolveFeatures(env) {
    return {
      reels: env.FEATURE_REELS !== "off",
      stories: env.FEATURE_STORIES !== "off",
      chat: env.FEATURE_CHAT === "on",
      live: env.FEATURE_LIVE === "on",
    };
  }

  it("should enable features by default", () => {
    const flags = resolveFeatures({});

    expect(flags.reels).toBe(true);
    expect(flags.stories).toBe(true);
    expect(flags.chat).toBe(false);
    expect(flags.live).toBe(false);
  });

  it("should disable features explicitly turned off", () => {
    const flags = resolveFeatures({
      FEATURE_REELS: "off",
      FEATURE_STORIES: "off",
    });

    expect(flags.reels).toBe(false);
    expect(flags.stories).toBe(false);
  });

  it("should enable features explicitly turned on", () => {
    const flags = resolveFeatures({
      FEATURE_CHAT: "on",
      FEATURE_LIVE: "on",
    });

    expect(flags.chat).toBe(true);
    expect(flags.live).toBe(true);
  });

  it("should combine mixed feature flags", () => {
    const flags = resolveFeatures({
      FEATURE_REELS: "off",
      FEATURE_CHAT: "on",
    });

    expect(flags.reels).toBe(false);
    expect(flags.chat).toBe(true);
    expect(flags.stories).toBe(true);
  });
});

describe("CONFIG / ENV PARSER", () => {
  function parseEnv(env) {
    return {
      PORT: Number(env.PORT || 3000),
      NODE_ENV: env.NODE_ENV || "development",
      JWT_SECRET: env.JWT_SECRET || null,
      REDIS_ENABLED: env.REDIS_ENABLED === "true",
    };
  }

  it("should parse numeric and string env values", () => {
    const env = {
      PORT: "8080",
      NODE_ENV: "production",
      JWT_SECRET: "secret",
      REDIS_ENABLED: "true",
    };

    const cfg = parseEnv(env);

    expect(cfg.PORT).toBe(8080);
    expect(cfg.NODE_ENV).toBe("production");
    expect(cfg.JWT_SECRET).toBe("secret");
    expect(cfg.REDIS_ENABLED).toBe(true);
  });

  it("should apply defaults when env is missing", () => {
    const cfg = parseEnv({});

    expect(cfg.PORT).toBe(3000);
    expect(cfg.NODE_ENV).toBe("development");
    expect(cfg.JWT_SECRET).toBe(null);
    expect(cfg.REDIS_ENABLED).toBe(false);
  });

  it("should handle boolean flags correctly", () => {
    const cfg = parseEnv({ REDIS_ENABLED: "false" });
    expect(cfg.REDIS_ENABLED).toBe(false);
  });
});

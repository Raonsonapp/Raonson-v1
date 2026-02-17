describe("UTILS / STRING", () => {
  function slugify(text) {
    return text
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/(^-|-$)+/g, "");
  }

  function truncate(text, max) {
    return text.length > max ? text.slice(0, max) + "…" : text;
  }

  it("should slugify text", () => {
    expect(slugify("Hello World!")).toBe("hello-world");
  });

  it("should remove extra symbols", () => {
    expect(slugify("  A  B  C ")).toBe("a-b-c");
  });

  it("should truncate long strings", () => {
    expect(truncate("abcdef", 3)).toBe("abc…");
  });

  it("should not truncate short strings", () => {
    expect(truncate("abc", 5)).toBe("abc");
  });
});

describe("FEED / PAGINATION LOGIC", () => {
  function paginate(items, page, limit) {
    const start = (page - 1) * limit;
    return items.slice(start, start + limit);
  }

  it("should return correct items for page 1", () => {
    const items = Array.from({ length: 30 }, (_, i) => i + 1);

    const page1 = paginate(items, 1, 10);

    expect(page1.length).toBe(10);
    expect(page1[0]).toBe(1);
    expect(page1[9]).toBe(10);
  });

  it("should return correct items for page 2", () => {
    const items = Array.from({ length: 30 }, (_, i) => i + 1);

    const page2 = paginate(items, 2, 10);

    expect(page2[0]).toBe(11);
    expect(page2[9]).toBe(20);
  });
});

describe("STORIES / HIGHLIGHTS RULES", () => {
  function canAddToHighlights({ isExpired, isOwner }) {
    return isExpired && isOwner;
  }

  it("should allow owner to highlight expired story", () => {
    const result = canAddToHighlights({
      isExpired: true,
      isOwner: true,
    });
    expect(result).toBe(true);
  });

  it("should block highlighting active story", () => {
    const result = canAddToHighlights({
      isExpired: false,
      isOwner: true,
    });
    expect(result).toBe(false);
  });

  it("should block non-owner from highlighting", () => {
    const result = canAddToHighlights({
      isExpired: true,
      isOwner: false,
    });
    expect(result).toBe(false);
  });
});

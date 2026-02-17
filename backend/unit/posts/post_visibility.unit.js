describe("POSTS / VISIBILITY RULES", () => {
  it("should show post if account is public", () => {
    const author = { isPrivate: false };
    const viewer = { id: "u2", following: [] };

    const canView = !author.isPrivate;
    expect(canView).toBe(true);
  });

  it("should hide post if account is private and not followed", () => {
    const author = { id: "u1", isPrivate: true };
    const viewer = { id: "u2", following: [] };

    const canView =
      !author.isPrivate || viewer.following.includes(author.id);

    expect(canView).toBe(false);
  });

  it("should show post if account is private but followed", () => {
    const author = { id: "u1", isPrivate: true };
    const viewer = { id: "u2", following: ["u1"] };

    const canView =
      !author.isPrivate || viewer.following.includes(author.id);

    expect(canView).toBe(true);
  });
});

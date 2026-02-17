describe("USERS / PRIVACY RULES", () => {
  it("should require follow approval for private accounts", () => {
    const user = { isPrivate: true };
    const canAutoFollow = !user.isPrivate;

    expect(canAutoFollow).toBe(false);
  });

  it("should allow auto follow for public accounts", () => {
    const user = { isPrivate: false };
    const canAutoFollow = !user.isPrivate;

    expect(canAutoFollow).toBe(true);
  });
});

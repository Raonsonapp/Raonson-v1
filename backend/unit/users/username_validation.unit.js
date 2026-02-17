describe("USERS / USERNAME VALIDATION", () => {
  it("should allow valid usernames", () => {
    const validUsernames = [
      "user123",
      "user_name",
      "user.name",
      "username_99",
    ];

    validUsernames.forEach((u) => {
      const isValid = /^[a-zA-Z0-9_.]+$/.test(u);
      expect(isValid).toBe(true);
    });
  });

  it("should reject invalid usernames", () => {
    const invalidUsernames = [
      "user name",
      "user-name",
      "user@name",
      "user#1",
    ];

    invalidUsernames.forEach((u) => {
      const isValid = /^[a-zA-Z0-9_.]+$/.test(u);
      expect(isValid).toBe(false);
    });
  });
});

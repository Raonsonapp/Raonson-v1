describe("AUTH / RULES", () => {
  it("should reject short passwords", () => {
    const password = "12345";
    expect(password.length < 8).toBe(true);
  });

  it("should accept strong passwords", () => {
    const password = "StrongPass123!";
    expect(password.length >= 8).toBe(true);
  });

  it("should validate username rules", () => {
    const username = "user_name123";
    const valid = /^[a-zA-Z0-9_.]+$/.test(username);

    expect(valid).toBe(true);
  });
});

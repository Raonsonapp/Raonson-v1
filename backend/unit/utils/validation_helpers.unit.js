describe("UTILS / VALIDATION HELPERS", () => {
  function isEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }

  function isUsername(name) {
    return /^[a-zA-Z0-9_.]{3,20}$/.test(name);
  }

  function isStrongPassword(pw) {
    return pw.length >= 8 && /[A-Z]/.test(pw) && /[0-9]/.test(pw);
  }

  it("should validate correct email", () => {
    expect(isEmail("test@example.com")).toBe(true);
  });

  it("should reject invalid email", () => {
    expect(isEmail("bad@mail")).toBe(false);
  });

  it("should validate username rules", () => {
    expect(isUsername("user_123")).toBe(true);
    expect(isUsername("ab")).toBe(false);
  });

  it("should validate strong password", () => {
    expect(isStrongPassword("Passw0rd")).toBe(true);
    expect(isStrongPassword("weak")).toBe(false);
  });
});

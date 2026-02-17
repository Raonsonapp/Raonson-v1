import bcrypt from "bcryptjs";

describe("AUTH / PASSWORD HASH", () => {
  it("should hash password correctly", async () => {
    const password = "TestPassword123!";
    const hash = await bcrypt.hash(password, 10);

    expect(hash).toBeDefined();
    expect(hash).not.toBe(password);

    const match = await bcrypt.compare(password, hash);
    expect(match).toBe(true);
  });

  it("should not match wrong password", async () => {
    const hash = await bcrypt.hash("CorrectPass", 10);
    const match = await bcrypt.compare("WrongPass", hash);

    expect(match).toBe(false);
  });
});

import jwt from "jsonwebtoken";
import { JWT_SECRET } from "../../src/config/jwt.config.js";

describe("AUTH / TOKEN VERIFY", () => {
  it("should verify valid token", () => {
    const payload = { id: "user123" };
    const token = jwt.sign(payload, JWT_SECRET);

    const decoded = jwt.verify(token, JWT_SECRET);
    expect(decoded.id).toBe(payload.id);
  });

  it("should throw error on invalid token", () => {
    expect(() =>
      jwt.verify("invalid.token.value", JWT_SECRET)
    ).toThrow();
  });
});

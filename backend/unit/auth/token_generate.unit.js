import jwt from "jsonwebtoken";
import { JWT_SECRET, JWT_EXPIRES_IN } from "../../src/config/jwt.config.js";

describe("AUTH / TOKEN GENERATE", () => {
  it("should generate valid JWT token", () => {
    const payload = { id: "user123" };
    const token = jwt.sign(payload, JWT_SECRET, {
      expiresIn: JWT_EXPIRES_IN,
    });

    expect(typeof token).toBe("string");
    expect(token.split(".").length).toBe(3);
  });
});

import request from "supertest";
import app from "../../src/app.js";

describe("HEALTH / SERVER", () => {
  it("should return server health status", async () => {
    const res = await request(app).get("/");

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty("status");
    expect(res.body.status).toMatch(/running/i);
  });
});

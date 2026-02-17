import request from "supertest";
import app from "../../src/app.js";
import {
  connectTestDB,
  clearTestDB,
  disconnectTestDB,
} from "../setup/test_database.js";

describe("HEALTH / API HEALTH", () => {
  beforeAll(async () => {
    await connectTestDB();
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should return API health status", async () => {
    const res = await request(app).get("/");

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty("status");
    expect(res.body.status).toMatch(/running/i);
  });

  it("should respond to unknown routes with 404", async () => {
    const res = await request(app).get("/__unknown_route__");

    expect(res.statusCode).toBe(404);
  });
});

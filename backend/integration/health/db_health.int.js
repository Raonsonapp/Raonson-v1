import mongoose from "mongoose";
import request from "supertest";
import app from "../../src/app.js";
import {
  connectTestDB,
  disconnectTestDB,
} from "../setup/test_database.js";

describe("HEALTH / DATABASE HEALTH", () => {
  beforeAll(async () => {
    await connectTestDB();
  });

  afterAll(async () => {
    await disconnectTestDB();
  });

  it("should confirm database connection is active", async () => {
    const state = mongoose.connection.readyState;

    // 1 = connected
    expect(state).toBe(1);
  });

  it("should allow a simple DB operation", async () => {
    const res = await request(app).get("/");

    expect(res.statusCode).toBe(200);
  });
});

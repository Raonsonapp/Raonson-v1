import mongoose from "mongoose";
import { connectDB } from "../../src/core/database.js";

describe("HEALTH / DATABASE", () => {
  beforeAll(async () => {
    await connectDB();
  });

  afterAll(async () => {
    await mongoose.connection.close();
  });

  it("should connect to database successfully", () => {
    const state = mongoose.connection.readyState;
    // 1 = connected
    expect(state).toBe(1);
  });
});

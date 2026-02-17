import request from "supertest";
import app from "../../src/app.js";
import {
  connectTestDB,
  clearTestDB,
  disconnectTestDB,
} from "../setup/test_database.js";

describe("CHAT / CREATE ROOM FLOW", () => {
  let tokenA, tokenB, userBId;

  beforeAll(async () => {
    await connectTestDB();

    // user A
    await request(app).post("/auth/register").send({
      username: "chat_user_a",
      email: "chatA@test.com",
      password: "Password123!",
    });

    const loginA = await request(app).post("/auth/login").send({
      email: "chatA@test.com",
      password: "Password123!",
    });

    tokenA = loginA.body.accessToken;

    // user B
    await request(app).post("/auth/register").send({
      username: "chat_user_b",
      email: "chatB@test.com",
      password: "Password123!",
    });

    const loginB = await request(app).post("/auth/login").send({
      email: "chatB@test.com",
      password: "Password123!",
    });

    tokenB = loginB.body.accessToken;
    userBId = loginB.body.user._id;
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should create a private chat room", async () => {
    const res = await request(app)
      .post("/chat/rooms")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({ userId: userBId });

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty("_id");
    expect(res.body.participants.length).toBe(2);
  });
});

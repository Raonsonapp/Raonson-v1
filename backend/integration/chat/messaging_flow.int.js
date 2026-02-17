import request from "supertest";
import app from "../../src/app.js";
import {
  connectTestDB,
  clearTestDB,
  disconnectTestDB,
} from "../setup/test_database.js";

describe("CHAT / MESSAGING FLOW", () => {
  let token, roomId;

  beforeAll(async () => {
    await connectTestDB();

    await request(app).post("/auth/register").send({
      username: "chat_message_user",
      email: "chatmsg@test.com",
      password: "Password123!",
    });

    const login = await request(app).post("/auth/login").send({
      email: "chatmsg@test.com",
      password: "Password123!",
    });

    token = login.body.accessToken;

    const room = await request(app)
      .post("/chat/rooms")
      .set("Authorization", `Bearer ${token}`)
      .send({ userId: login.body.user._id });

    roomId = room.body._id;
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should send message to chat room", async () => {
    const res = await request(app)
      .post(`/chat/rooms/${roomId}/messages`)
      .set("Authorization", `Bearer ${token}`)
      .send({ text: "Hello from integration test" });

    expect(res.statusCode).toBe(200);
    expect(res.body.text).toBe("Hello from integration test");
  });

  it("should fetch chat messages", async () => {
    const res = await request(app)
      .get(`/chat/rooms/${roomId}/messages`)
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThanOrEqual(1);
  });
});

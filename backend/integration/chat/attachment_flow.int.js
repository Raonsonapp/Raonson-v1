import request from "supertest";
import app from "../../src/app.js";
import {
  connectTestDB,
  clearTestDB,
  disconnectTestDB,
} from "../setup/test_database.js";

describe("CHAT / ATTACHMENT FLOW", () => {
  let token, roomId;

  beforeAll(async () => {
    await connectTestDB();

    await request(app).post("/auth/register").send({
      username: "chat_attach_user",
      email: "chatattach@test.com",
      password: "Password123!",
    });

    const login = await request(app).post("/auth/login").send({
      email: "chatattach@test.com",
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

  it("should send message with attachment metadata", async () => {
    const res = await request(app)
      .post(`/chat/rooms/${roomId}/messages`)
      .set("Authorization", `Bearer ${token}`)
      .send({
        text: "",
        attachment: {
          url: "https://cdn.test/file.pdf",
          type: "file",
        },
      });

    expect(res.statusCode).toBe(200);
    expect(res.body.attachment).toHaveProperty("url");
  });
});

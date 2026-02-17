import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let token;
let roomId;

beforeAll(async () => {
  server = await startServer();

  await request(server).post("/auth/register").send({
    username: "media_sender",
    email: "media@test.com",
    password: "Media123!",
  });

  const login = await request(server).post("/auth/login").send({
    email: "media@test.com",
    password: "Media123!",
  });

  token = login.body.accessToken;

  const room = await request(server)
    .post("/chat/room")
    .set("Authorization", `Bearer ${token}`)
    .send({ username: "media_sender" });

  roomId = room.body._id;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E CHAT — Media message", () => {
  test("Send image message", async () => {
    const res = await request(server)
      .post("/chat/message")
      .set("Authorization", `Bearer ${token}`)
      .send({
        roomId,
        mediaUrl: "https://cdn.raonson/chat/image1.jpg",
        mediaType: "image",
      })
      .expect(200);

    expect(res.body.mediaUrl).toContain("image1.jpg");
    expect(res.body.mediaType).toBe("image");
  });

  test("Send video message", async () => {
    const res = await request(server)
      .post("/chat/message")
      .set("Authorization", `Bearer ${token}`)
      .send({
        roomId,
        mediaUrl: "https://cdn.raonson/chat/video1.mp4",
        mediaType: "video",
      })
      .expect(200);

    expect(res.body.mediaType).toBe("video");
  });
});

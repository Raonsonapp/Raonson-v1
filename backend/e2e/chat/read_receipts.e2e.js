import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let tokenA;
let tokenB;
let roomId;
let messageId;

beforeAll(async () => {
  server = await startServer();

  await request(server).post("/auth/register").send({
    username: "reader_a",
    email: "readera@test.com",
    password: "Read123!",
  });

  await request(server).post("/auth/register").send({
    username: "reader_b",
    email: "readerb@test.com",
    password: "Read123!",
  });

  const loginA = await request(server).post("/auth/login").send({
    email: "readera@test.com",
    password: "Read123!",
  });
  tokenA = loginA.body.accessToken;

  const loginB = await request(server).post("/auth/login").send({
    email: "readerb@test.com",
    password: "Read123!",
  });
  tokenB = loginB.body.accessToken;

  const room = await request(server)
    .post("/chat/room")
    .set("Authorization", `Bearer ${tokenA}`)
    .send({ username: "reader_b" });

  roomId = room.body._id;

  const msg = await request(server)
    .post("/chat/message")
    .set("Authorization", `Bearer ${tokenA}`)
    .send({ roomId, text: "Seen?" });

  messageId = msg.body._id;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E CHAT — Read receipts", () => {
  test("Message initially unread", async () => {
    const res = await request(server)
      .get(`/chat/room/${roomId}`)
      .set("Authorization", `Bearer ${tokenA}`)
      .expect(200);

    const msg = res.body.messages.find(m => m._id === messageId);
    expect(msg.readBy.length).toBe(1); // sender only
  });

  test("Recipient reads message", async () => {
    await request(server)
      .post(`/chat/message/${messageId}/read`)
      .set("Authorization", `Bearer ${tokenB}`)
      .expect(200);

    const res = await request(server)
      .get(`/chat/room/${roomId}`)
      .set("Authorization", `Bearer ${tokenA}`)
      .expect(200);

    const msg = res.body.messages.find(m => m._id === messageId);
    expect(msg.readBy.length).toBe(2);
  });
});

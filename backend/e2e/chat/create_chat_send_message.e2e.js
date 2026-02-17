import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let tokenA;
let tokenB;
let roomId;

beforeAll(async () => {
  server = await startServer();

  await request(server).post("/auth/register").send({
    username: "alice_dm",
    email: "alice@dm.test",
    password: "Alice123!",
  });

  await request(server).post("/auth/register").send({
    username: "bob_dm",
    email: "bob@dm.test",
    password: "Bob123!",
  });

  const loginA = await request(server).post("/auth/login").send({
    email: "alice@dm.test",
    password: "Alice123!",
  });
  tokenA = loginA.body.accessToken;

  const loginB = await request(server).post("/auth/login").send({
    email: "bob@dm.test",
    password: "Bob123!",
  });
  tokenB = loginB.body.accessToken;

  const room = await request(server)
    .post("/chat/room")
    .set("Authorization", `Bearer ${tokenA}`)
    .send({ username: "bob_dm" });

  roomId = room.body._id;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E CHAT — Create room & send message", () => {
  test("Room created", () => {
    expect(roomId).toBeDefined();
  });

  test("User sends message", async () => {
    const res = await request(server)
      .post("/chat/message")
      .set("Authorization", `Bearer ${tokenA}`)
      .send({
        roomId,
        text: "Hello Bob 👋",
      })
      .expect(200);

    expect(res.body.text).toBe("Hello Bob 👋");
    expect(res.body.room).toBe(roomId);
  });

  test("Second user receives message", async () => {
    const res = await request(server)
      .get(`/chat/room/${roomId}`)
      .set("Authorization", `Bearer ${tokenB}`)
      .expect(200);

    expect(res.body.messages.length).toBeGreaterThanOrEqual(1);
  });
});

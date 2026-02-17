import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let token;

beforeAll(async () => {
  server = await startServer();

  await request(server).post("/auth/register").send({
    username: "notifuser",
    email: "notif@test.com",
    password: "Test123!",
  });

  const login = await request(server).post("/auth/login").send({
    email: "notif@test.com",
    password: "Test123!",
  });

  token = login.body.accessToken;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E SETTINGS — Notification Preferences", () => {
  test("Disable like notifications", async () => {
    const res = await request(server)
      .patch("/settings/notifications")
      .set("Authorization", `Bearer ${token}`)
      .send({
        likes: false,
        comments: true,
        follows: true,
      })
      .expect(200);

    expect(res.body.likes).toBe(false);
  });

  test("Enable all notifications", async () => {
    const res = await request(server)
      .patch("/settings/notifications")
      .set("Authorization", `Bearer ${token}`)
      .send({
        likes: true,
        comments: true,
        follows: true,
      })
      .expect(200);

    expect(res.body.likes).toBe(true);
    expect(res.body.comments).toBe(true);
    expect(res.body.follows).toBe(true);
  });
});

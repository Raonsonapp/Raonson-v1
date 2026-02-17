import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let token;
let notificationId;

beforeAll(async () => {
  server = await startServer();

  await request(server).post("/auth/register").send({
    username: "notif_user",
    email: "notif_user@test.com",
    password: "Notif123!",
  });

  const login = await request(server).post("/auth/login").send({
    email: "notif_user@test.com",
    password: "Notif123!",
  });
  token = login.body.accessToken;

  // create self notification (follow self for test)
  await request(server)
    .post("/follow/notif_user")
    .set("Authorization", `Bearer ${token}`);

  const list = await request(server)
    .get("/notifications")
    .set("Authorization", `Bearer ${token}`);

  notificationId = list.body[0]._id;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E NOTIFICATIONS — Open", () => {
  test("Notification unread by default", async () => {
    const res = await request(server)
      .get("/notifications")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    const notif = res.body.find(n => n._id === notificationId);
    expect(notif.read).toBe(false);
  });

  test("Open notification marks as read", async () => {
    await request(server)
      .post(`/notifications/${notificationId}/read`)
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    const res = await request(server)
      .get("/notifications")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    const notif = res.body.find(n => n._id === notificationId);
    expect(notif.read).toBe(true);
  });
});

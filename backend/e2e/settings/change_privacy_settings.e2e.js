import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let token;
let userId;

beforeAll(async () => {
  server = await startServer();

  await request(server).post("/auth/register").send({
    username: "privateuser",
    email: "private@test.com",
    password: "Test123!",
  });

  const login = await request(server).post("/auth/login").send({
    email: "private@test.com",
    password: "Test123!",
  });

  token = login.body.accessToken;
  userId = login.body.user._id;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E SETTINGS — Privacy Toggle", () => {
  test("Enable private account", async () => {
    const res = await request(server)
      .patch("/settings/privacy")
      .set("Authorization", `Bearer ${token}`)
      .send({ isPrivate: true })
      .expect(200);

    expect(res.body.isPrivate).toBe(true);
  });

  test("Disable private account", async () => {
    const res = await request(server)
      .patch("/settings/privacy")
      .set("Authorization", `Bearer ${token}`)
      .send({ isPrivate: false })
      .expect(200);

    expect(res.body.isPrivate).toBe(false);
  });
});

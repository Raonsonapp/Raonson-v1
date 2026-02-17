import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let token;

beforeAll(async () => {
  server = await startServer();

  await request(server).post("/auth/register").send({
    username: "private_user",
    email: "private@test.com",
    password: "Test123!",
  });

  const login = await request(server).post("/auth/login").send({
    email: "private@test.com",
    password: "Test123!",
  });

  token = login.body.accessToken;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E PROFILE — Privacy Toggle", () => {
  test("Set profile to private", async () => {
    await request(server)
      .put("/profile/privacy")
      .set("Authorization", `Bearer ${token}`)
      .send({ isPrivate: true })
      .expect(200);

    const res = await request(server)
      .get("/profile/me")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    expect(res.body.isPrivate).toBe(true);
  });

  test("Set profile to public", async () => {
    await request(server)
      .put("/profile/privacy")
      .set("Authorization", `Bearer ${token}`)
      .send({ isPrivate: false })
      .expect(200);

    const res = await request(server)
      .get("/profile/me")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    expect(res.body.isPrivate).toBe(false);
  });
});

import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;

beforeAll(async () => {
  server = await startServer();
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E AUTH — Register & Login", () => {
  const userData = {
    username: "e2e_auth_user",
    email: "e2e_auth_user@test.com",
    password: "StrongPass123!",
  };

  test("User can register", async () => {
    const res = await request(server)
      .post("/auth/register")
      .send(userData)
      .expect(201);

    expect(res.body).toHaveProperty("user");
    expect(res.body.user.username).toBe(userData.username);
  });

  test("User can login", async () => {
    const res = await request(server)
      .post("/auth/login")
      .send({
        email: userData.email,
        password: userData.password,
      })
      .expect(200);

    expect(res.body).toHaveProperty("accessToken");
    expect(res.body).toHaveProperty("refreshToken");
  });
});

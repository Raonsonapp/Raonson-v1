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

describe("E2E AUTH — Password Reset", () => {
  const email = "reset_user@test.com";

  beforeAll(async () => {
    await request(server)
      .post("/auth/register")
      .send({
        username: "reset_user",
        email,
        password: "OldPassword123!",
      })
      .expect(201);
  });

  test("User can request password reset", async () => {
    const res = await request(server)
      .post("/auth/request-password-reset")
      .send({ email })
      .expect(200);

    expect(res.body).toHaveProperty("resetToken");
  });

  test("User can reset password with token", async () => {
    const requestRes = await request(server)
      .post("/auth/request-password-reset")
      .send({ email });

    const { resetToken } = requestRes.body;

    const resetRes = await request(server)
      .post("/auth/reset-password")
      .send({
        token: resetToken,
        newPassword: "NewPassword123!",
      })
      .expect(200);

    expect(resetRes.body.success).toBe(true);
  });
});

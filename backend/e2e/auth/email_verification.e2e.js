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

describe("E2E AUTH — Email Verification", () => {
  test("User email verification flow", async () => {
    const registerRes = await request(server)
      .post("/auth/register")
      .send({
        username: "verify_user",
        email: "verify_user@test.com",
        password: "VerifyPass123!",
      })
      .expect(201);

    const { verificationToken } = registerRes.body;

    expect(verificationToken).toBeDefined();

    const verifyRes = await request(server)
      .post("/auth/verify-email")
      .send({ token: verificationToken })
      .expect(200);

    expect(verifyRes.body.verified).toBe(true);
  });
});

import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let accessToken;

beforeAll(async () => {
  server = await startServer();

  // create base users
  for (let i = 1; i <= 5; i++) {
    await request(server)
      .post("/auth/register")
      .send({
        username: `suggest_user_${i}`,
        email: `suggest_${i}@test.com`,
        password: "SuggestPass123!",
      });
  }

  const login = await request(server)
    .post("/auth/login")
    .send({
      email: "suggest_1@test.com",
      password: "SuggestPass123!",
    });

  accessToken = login.body.accessToken;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E ONBOARDING — Follow Suggestions", () => {
  test("User receives follow suggestions", async () => {
    const res = await request(server)
      .get("/users/suggestions")
      .set("Authorization", `Bearer ${accessToken}`)
      .expect(200);

    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThan(0);
    expect(res.body[0]).toHaveProperty("username");
  });
});

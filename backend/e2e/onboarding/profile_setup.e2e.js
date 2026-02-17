import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let accessToken;

beforeAll(async () => {
  server = await startServer();

  const register = await request(server)
    .post("/auth/register")
    .send({
      username: "onboard_user",
      email: "onboard_user@test.com",
      password: "OnboardPass123!",
    });

  const login = await request(server)
    .post("/auth/login")
    .send({
      email: "onboard_user@test.com",
      password: "OnboardPass123!",
    });

  accessToken = login.body.accessToken;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E ONBOARDING — Profile Setup", () => {
  test("User can complete profile setup", async () => {
    const res = await request(server)
      .put("/profile")
      .set("Authorization", `Bearer ${accessToken}`)
      .send({
        bio: "Hello, this is my profile",
        avatar: "https://cdn.raonson/avatar.png",
        isPrivate: false,
      })
      .expect(200);

    expect(res.body.profile.bio).toBe("Hello, this is my profile");
    expect(res.body.profile.avatar).toContain("http");
  });
});

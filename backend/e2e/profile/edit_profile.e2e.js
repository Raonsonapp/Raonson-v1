import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let token;
let userId;

beforeAll(async () => {
  server = await startServer();

  await request(server).post("/auth/register").send({
    username: "profile_edit",
    email: "profile_edit@test.com",
    password: "Test123!",
  });

  const login = await request(server).post("/auth/login").send({
    email: "profile_edit@test.com",
    password: "Test123!",
  });

  token = login.body.accessToken;
  userId = login.body.user._id;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E PROFILE — Edit", () => {
  test("Edit profile bio and avatar", async () => {
    await request(server)
      .put("/profile")
      .set("Authorization", `Bearer ${token}`)
      .send({
        bio: "Updated bio",
        avatar: "https://cdn.raonson/avatar/new.jpg",
      })
      .expect(200);

    const res = await request(server)
      .get(`/profile/${userId}`)
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    expect(res.body.bio).toBe("Updated bio");
    expect(res.body.avatar).toContain("cdn.raonson");
  });
});

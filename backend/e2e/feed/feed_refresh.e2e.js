import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let token;

beforeAll(async () => {
  server = await startServer();

  await request(server).post("/auth/register").send({
    username: "refresh_user",
    email: "refresh_user@test.com",
    password: "RefreshPass123!",
  });

  const login = await request(server).post("/auth/login").send({
    email: "refresh_user@test.com",
    password: "RefreshPass123!",
  });

  token = login.body.accessToken;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E FEED — Refresh", () => {
  test("Feed refresh shows newest post first", async () => {
    await request(server)
      .post("/posts")
      .set("Authorization", `Bearer ${token}`)
      .send({
        caption: "Old post",
        media: [{ url: "https://cdn.raonson/old.png", type: "image" }],
      });

    await new Promise(r => setTimeout(r, 50));

    await request(server)
      .post("/posts")
      .set("Authorization", `Bearer ${token}`)
      .send({
        caption: "Newest post",
        media: [{ url: "https://cdn.raonson/new.png", type: "image" }],
      });

    const res = await request(server)
      .get("/feed")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    expect(res.body[0].caption).toBe("Newest post");
  });
});

import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let token;

beforeAll(async () => {
  server = await startServer();

  await request(server).post("/auth/register").send({
    username: "page_user",
    email: "page_user@test.com",
    password: "PagePass123!",
  });

  const login = await request(server).post("/auth/login").send({
    email: "page_user@test.com",
    password: "PagePass123!",
  });

  token = login.body.accessToken;

  for (let i = 0; i < 30; i++) {
    await request(server)
      .post("/posts")
      .set("Authorization", `Bearer ${token}`)
      .send({
        caption: `Paged Post ${i}`,
        media: [{ url: "https://cdn.raonson/img.png", type: "image" }],
      });
  }
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E FEED — Infinite Pagination", () => {
  test("Feed paginates correctly", async () => {
    const first = await request(server)
      .get("/feed?limit=10")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    const second = await request(server)
      .get(`/feed?limit=10&cursor=${first.body.at(-1)._id}`)
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    expect(first.body.length).toBe(10);
    expect(second.body.length).toBe(10);
    expect(first.body[0]._id).not.toBe(second.body[0]._id);
  });
});

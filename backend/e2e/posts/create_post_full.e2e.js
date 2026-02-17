import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let token;

beforeAll(async () => {
  server = await startServer();

  await request(server).post("/auth/register").send({
    username: "post_creator",
    email: "creator@test.com",
    password: "CreatePost123!",
  });

  const login = await request(server).post("/auth/login").send({
    email: "creator@test.com",
    password: "CreatePost123!",
  });

  token = login.body.accessToken;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E POSTS — Create Post (Full)", () => {
  test("User creates post with media", async () => {
    const res = await request(server)
      .post("/posts")
      .set("Authorization", `Bearer ${token}`)
      .send({
        caption: "Hello Raonson",
        media: [
          { url: "https://cdn.raonson/img1.png", type: "image" },
          { url: "https://cdn.raonson/video.mp4", type: "video" },
        ],
      })
      .expect(200);

    expect(res.body.caption).toBe("Hello Raonson");
    expect(res.body.media.length).toBe(2);
  });
});

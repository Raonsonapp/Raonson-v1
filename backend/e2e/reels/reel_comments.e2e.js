import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let token;
let reelId;

beforeAll(async () => {
  server = await startServer();

  await request(server).post("/auth/register").send({
    username: "reel_commenter",
    email: "reelcomment@test.com",
    password: "Comment123!",
  });

  const login = await request(server).post("/auth/login").send({
    email: "reelcomment@test.com",
    password: "Comment123!",
  });

  token = login.body.accessToken;

  const reel = await request(server)
    .post("/reels")
    .set("Authorization", `Bearer ${token}`)
    .send({
      mediaUrl: "https://cdn.raonson/reel_comment.mp4",
      caption: "Commentable reel",
    });

  reelId = reel.body._id;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E REELS — Comments", () => {
  test("User comments on reel", async () => {
    const res = await request(server)
      .post("/comments")
      .set("Authorization", `Bearer ${token}`)
      .send({
        targetType: "reel",
        targetId: reelId,
        text: "🔥🔥🔥",
      })
      .expect(200);

    expect(res.body.text).toBe("🔥🔥🔥");
  });

  test("Comments appear under reel", async () => {
    const res = await request(server)
      .get(`/comments/reel/${reelId}`)
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThanOrEqual(1);
  });
});

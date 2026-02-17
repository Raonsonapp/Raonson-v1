import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let token;

beforeAll(async () => {
  server = await startServer();

  await request(server).post("/auth/register").send({
    username: "story_creator",
    email: "story@test.com",
    password: "StoryCreate123!",
  });

  const login = await request(server).post("/auth/login").send({
    email: "story@test.com",
    password: "StoryCreate123!",
  });

  token = login.body.accessToken;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E STORIES — Create Story", () => {
  test("User creates a story", async () => {
    const res = await request(server)
      .post("/stories")
      .set("Authorization", `Bearer ${token}`)
      .send({
        mediaUrl: "https://cdn.raonson/story1.jpg",
        mediaType: "image",
      })
      .expect(200);

    expect(res.body.mediaUrl).toBeDefined();
    expect(res.body.mediaType).toBe("image");
  });
});

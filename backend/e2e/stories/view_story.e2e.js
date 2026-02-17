import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let creatorToken;
let viewerToken;
let storyId;

beforeAll(async () => {
  server = await startServer();

  // creator
  await request(server).post("/auth/register").send({
    username: "story_owner",
    email: "owner@test.com",
    password: "Owner123!",
  });

  const ownerLogin = await request(server).post("/auth/login").send({
    email: "owner@test.com",
    password: "Owner123!",
  });

  creatorToken = ownerLogin.body.accessToken;

  // viewer
  await request(server).post("/auth/register").send({
    username: "story_viewer",
    email: "viewer@test.com",
    password: "Viewer123!",
  });

  const viewerLogin = await request(server).post("/auth/login").send({
    email: "viewer@test.com",
    password: "Viewer123!",
  });

  viewerToken = viewerLogin.body.accessToken;

  const story = await request(server)
    .post("/stories")
    .set("Authorization", `Bearer ${creatorToken}`)
    .send({
      mediaUrl: "https://cdn.raonson/story_view.jpg",
      mediaType: "image",
    });

  storyId = story.body._id;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E STORIES — View Story", () => {
  test("User views a story", async () => {
    const res = await request(server)
      .post(`/stories/${storyId}/view`)
      .set("Authorization", `Bearer ${viewerToken}`)
      .expect(200);

    expect(res.body.views).toBeGreaterThanOrEqual(1);
  });
});

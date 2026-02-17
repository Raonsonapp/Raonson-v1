import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let token;
let postId;

beforeAll(async () => {
  server = await startServer();

  await request(server).post("/auth/register").send({
    username: "editor",
    email: "editor@test.com",
    password: "EditPost123!",
  });

  const login = await request(server).post("/auth/login").send({
    email: "editor@test.com",
    password: "EditPost123!",
  });

  token = login.body.accessToken;

  const post = await request(server)
    .post("/posts")
    .set("Authorization", `Bearer ${token}`)
    .send({
      caption: "Original caption",
      media: [{ url: "https://cdn.raonson/img.png", type: "image" }],
    });

  postId = post.body._id;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E POSTS — Edit & Delete", () => {
  test("User edits own post", async () => {
    const res = await request(server)
      .put(`/posts/${postId}`)
      .set("Authorization", `Bearer ${token}`)
      .send({ caption: "Updated caption" })
      .expect(200);

    expect(res.body.caption).toBe("Updated caption");
  });

  test("User deletes own post", async () => {
    await request(server)
      .delete(`/posts/${postId}`)
      .set("Authorization", `Bearer ${token}`)
      .expect(200);
  });
});

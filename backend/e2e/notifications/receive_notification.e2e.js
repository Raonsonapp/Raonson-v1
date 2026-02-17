import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let tokenA;
let tokenB;
let postId;

beforeAll(async () => {
  server = await startServer();

  // register users
  await request(server).post("/auth/register").send({
    username: "notif_sender",
    email: "notif_sender@test.com",
    password: "Notif123!",
  });

  await request(server).post("/auth/register").send({
    username: "notif_receiver",
    email: "notif_receiver@test.com",
    password: "Notif123!",
  });

  // login
  const loginA = await request(server).post("/auth/login").send({
    email: "notif_sender@test.com",
    password: "Notif123!",
  });
  tokenA = loginA.body.accessToken;

  const loginB = await request(server).post("/auth/login").send({
    email: "notif_receiver@test.com",
    password: "Notif123!",
  });
  tokenB = loginB.body.accessToken;

  // create post by receiver
  const post = await request(server)
    .post("/posts")
    .set("Authorization", `Bearer ${tokenB}`)
    .send({
      caption: "Notification test post",
      media: [{ url: "https://cdn.raonson/post/1.jpg", type: "image" }],
    });

  postId = post.body._id;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E NOTIFICATIONS — Receive", () => {
  test("Like triggers notification", async () => {
    await request(server)
      .post(`/posts/${postId}/like`)
      .set("Authorization", `Bearer ${tokenA}`)
      .expect(200);

    const res = await request(server)
      .get("/notifications")
      .set("Authorization", `Bearer ${tokenB}`)
      .expect(200);

    expect(res.body.length).toBeGreaterThanOrEqual(1);

    const notif = res.body.find(n => n.type === "like");
    expect(notif).toBeDefined();
    expect(notif.actor.username).toBe("notif_sender");
  });

  test("Comment triggers notification", async () => {
    await request(server)
      .post(`/posts/${postId}/comment`)
      .set("Authorization", `Bearer ${tokenA}`)
      .send({ text: "Nice post!" })
      .expect(200);

    const res = await request(server)
      .get("/notifications")
      .set("Authorization", `Bearer ${tokenB}`)
      .expect(200);

    const notif = res.body.find(n => n.type === "comment");
    expect(notif).toBeDefined();
  });
});

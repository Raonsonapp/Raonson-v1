import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";
import { cleanupDatabase } from "../setup/cleanup.js";

let server;
let token;
let userId;

beforeAll(async () => {
  server = await startServer();

  await request(server).post("/auth/register").send({
    username: "profile_view",
    email: "profile_view@test.com",
    password: "Test123!",
  });

  const login = await request(server).post("/auth/login").send({
    email: "profile_view@test.com",
    password: "Test123!",
  });

  token = login.body.accessToken;
  userId = login.body.user._id;
});

afterAll(async () => {
  await cleanupDatabase();
  await stopServer();
});

describe("E2E PROFILE — View", () => {
  test("View own profile", async () => {
    const res = await request(server)
      .get(`/profile/${userId}`)
      .set("Authorization", `Bearer ${token}`)
      .expect(200);

    expect(res.body.username).toBe("profile_view");
    expect(res.body).toHaveProperty("followersCount");
    expect(res.body).toHaveProperty("followingCount");
  });
});

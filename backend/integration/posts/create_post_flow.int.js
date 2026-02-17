import request from "supertest";
import app from "../../src/app.js";
import {
  connectTestDB,
  clearTestDB,
  disconnectTestDB,
} from "../setup/test_database.js";

describe("POSTS / CREATE POST FLOW", () => {
  let token;

  beforeAll(async () => {
    await connectTestDB();

    await request(app).post("/auth/register").send({
      username: "post_creator",
      email: "post@test.com",
      password: "Password123!",
    });

    const login = await request(app).post("/auth/login").send({
      email: "post@test.com",
      password: "Password123!",
    });

    token = login.body.accessToken;
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should create a new post", async () => {
    const res = await request(app)
      .post("/posts")
      .set("Authorization", `Bearer ${token}`)
      .send({
        caption: "My first post",
        media: [{ url: "https://cdn.test/image.jpg", type: "image" }],
      });

    expect(res.statusCode).toBe(200);
    expect(res.body.caption).toBe("My first post");
    expect(res.body.media.length).toBe(1);
  });
});

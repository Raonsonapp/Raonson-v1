import request from "supertest";
import app from "../../src/app.js";
import {
  connectTestDB,
  clearTestDB,
  disconnectTestDB,
} from "../setup/test_database.js";

describe("STORIES / VIEW FLOW", () => {
  let token, storyId;

  beforeAll(async () => {
    await connectTestDB();

    await request(app).post("/auth/register").send({
      username: "story_viewer",
      email: "story_viewer@test.com",
      password: "Password123!",
    });

    const login = await request(app).post("/auth/login").send({
      email: "story_viewer@test.com",
      password: "Password123!",
    });

    token = login.body.accessToken;

    const story = await request(app)
      .post("/stories")
      .set("Authorization", `Bearer ${token}`)
      .send({
        mediaUrl: "https://cdn.test/story_view.jpg",
        mediaType: "image",
      });

    storyId = story.body._id;
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should mark story as viewed", async () => {
    const res = await request(app)
      .post(`/stories/${storyId}/view`)
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.views).toBeGreaterThanOrEqual(1);
  });
});

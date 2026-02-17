import request from "supertest";
import app from "../../src/app.js";
import {
  connectTestDB,
  clearTestDB,
  disconnectTestDB,
} from "../setup/test_database.js";

describe("FEED / PAGINATION FLOW", () => {
  let token;

  beforeAll(async () => {
    await connectTestDB();

    await request(app).post("/auth/register").send({
      username: "pager",
      email: "pager@test.com",
      password: "Password123!",
    });

    const login = await request(app).post("/auth/login").send({
      email: "pager@test.com",
      password: "Password123!",
    });

    token = login.body.accessToken;

    for (let i = 0; i < 12; i++) {
      await request(app)
        .post("/posts")
        .set("Authorization", `Bearer ${token}`)
        .send({
          caption: `Paginated ${i}`,
          media: [{ url: `https://cdn.test/p${i}.jpg`, type: "image" }],
        });
    }
  });

  afterAll(async () => {
    await clearTestDB();
    await disconnectTestDB();
  });

  it("should paginate feed", async () => {
    const res = await request(app)
      .get("/feed?limit=5&page=1")
      .set("Authorization", `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.length).toBe(5);
  });
});

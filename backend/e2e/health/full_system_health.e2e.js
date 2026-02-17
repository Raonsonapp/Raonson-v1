import request from "supertest";
import { startServer, stopServer } from "../setup/start_server.js";

let server;

beforeAll(async () => {
  server = await startServer();
});

afterAll(async () => {
  await stopServer();
});

describe("E2E HEALTH — Full System Health", () => {
  test("API root health check", async () => {
    const res = await request(server)
      .get("/")
      .expect(200);

    expect(res.body.status).toBe("Raonson backend running ✅");
  });

  test("Database health endpoint", async () => {
    const res = await request(server)
      .get("/health/db")
      .expect(200);

    expect(res.body.database).toBe("connected");
  });

  test("Cache health endpoint", async () => {
    const res = await request(server)
      .get("/health/cache")
      .expect(200);

    expect(["connected", "disabled"]).toContain(res.body.cache);
  });
});

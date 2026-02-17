import request from "supertest";
import { startServer, stopServer, restartServer } from "../setup/start_server.js";

let server;

describe("E2E HEALTH — Restart & Recovery", () => {
  test("Server restarts and recovers correctly", async () => {
    server = await startServer();

    const first = await request(server)
      .get("/")
      .expect(200);

    expect(first.body.status).toBe("Raonson backend running ✅");

    await restartServer();

    const afterRestart = await request(server)
      .get("/")
      .expect(200);

    expect(afterRestart.body.status).toBe("Raonson backend running ✅");

    await stopServer();
  });
});

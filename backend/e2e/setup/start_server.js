import http from "http";
import mongoose from "mongoose";
import app from "../../src/app.js";
import { E2E_ENV } from "./e2e_env.js";

let server;

export async function startServer() {
  if (mongoose.connection.readyState !== 1) {
    await mongoose.connect(E2E_ENV.MONGO_URI);
  }

  server = http.createServer(app);

  await new Promise((resolve) => {
    server.listen(4000, resolve);
  });

  return server;
}

export async function stopServer() {
  if (server) {
    await new Promise((resolve) => server.close(resolve));
    server = null;
  }

  if (mongoose.connection.readyState === 1) {
    await mongoose.disconnect();
  }
}

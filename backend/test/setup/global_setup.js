// backend/test/setup/global_setup.js
import "./test_env.js";
import { connectTestDB, clearTestDB, closeTestDB } from "./test_db.js";

beforeAll(async () => {
  await connectTestDB();
});

beforeEach(async () => {
  await clearTestDB();
});

afterAll(async () => {
  await closeTestDB();
});

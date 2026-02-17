import { clearTestDB, disconnectTestDB } from "./test_database.js";

export async function integrationCleanup() {
  try {
    await clearTestDB();
  } finally {
    await disconnectTestDB();
  }
}

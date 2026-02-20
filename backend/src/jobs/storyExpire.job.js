import { Story } from "../models/story.model.js";

export async function runStoryExpireJob() {
  const expiryTime = new Date(Date.now() - 24 * 60 * 60 * 1000);

  const expired = await Story.find({
    createdAt: { $lt: expiryTime },
  }).select("_id");

  if (expired.length > 0) {
    await Story.deleteMany({ _id: { $in: expired.map(s => s._id) } });
  }

  return {
    expiredStories: expired.length,
  };
}

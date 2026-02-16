import { User } from "../models/user.model.js";
import { Post } from "../models/post.model.js";
import { Search } from "../models/search.model.js";

export async function searchAll({ userId, q }) {
  if (!q || q.trim().length < 1) return { users: [], hashtags: [] };

  const regex = new RegExp("^" + q, "i");

  // USERS
  const users = await User.find({ username: regex })
    .select("username avatar verified isPrivate followersCount")
    .limit(20);

  // HASHTAGS (from captions)
  const hashtags = await Post.aggregate([
    { $match: { caption: { $regex: `#${q}`, $options: "i" } } },
    {
      $project: {
        tags: {
          $regexFindAll: {
            input: "$caption",
            regex: /#\w+/g,
          },
        },
      },
    },
    { $unwind: "$tags" },
    {
      $group: {
        _id: "$tags.match",
        count: { $sum: 1 },
      },
    },
    { $sort: { count: -1 } },
    { $limit: 10 },
  ]);

  // SAVE RECENT SEARCH
  await Search.create({
    user: userId,
    query: q,
    type: "user",
  });

  return { users, hashtags };
}

export async function getRecentSearches(userId) {
  return Search.find({ user: userId })
    .sort({ createdAt: -1 })
    .limit(10);
}

export async function clearRecentSearches(userId) {
  await Search.deleteMany({ user: userId });
}

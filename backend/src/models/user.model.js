import mongoose from "mongoose";

const UserSchema = new mongoose.Schema(
  {
    username: { type: String, required: true, unique: true },
    avatar: { type: String, default: "" },
    verified: { type: Boolean, default: false },

    // 🔐 PRIVACY
    isPrivate: { type: Boolean, default: false },

    // 👥 FOLLOW SYSTEM
    followers: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
    following: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],

    // 📨 FOLLOW REQUESTS (for private accounts)
    followRequests: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],

    // 📊 COUNTERS (fast access)
    postsCount: { type: Number, default: 0 },
    followersCount: { type: Number, default: 0 },
    followingCount: { type: Number, default: 0 },
  },
  { timestamps: true }
);

export const User = mongoose.model("User", UserSchema);

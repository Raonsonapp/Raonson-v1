import mongoose from "mongoose";

const UserSchema = new mongoose.Schema(
  {
    username: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      index: true,
    },

    email: {
      type: String,
      unique: true,
      sparse: true,
      lowercase: true,
      trim: true,
    },

    password: {
      type: String,
      required: true,
      select: false, // 🔐 NEVER return password
    },

    avatar: { type: String, default: "" },
    verified: { type: Boolean, default: false },

    // 🔐 PRIVACY
    isPrivate: { type: Boolean, default: false },

    // 👥 FOLLOW SYSTEM
    followers: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
    following: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],

    // 📨 FOLLOW REQUESTS
    followRequests: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],

    // 📊 COUNTERS
    postsCount: { type: Number, default: 0 },
    followersCount: { type: Number, default: 0 },
    followingCount: { type: Number, default: 0 },
  },
  { timestamps: true }
);

// 🔍 indexes for feed / search
UserSchema.index({ username: 1 });

export const User = mongoose.model("User", UserSchema);

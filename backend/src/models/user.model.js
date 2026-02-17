import mongoose from "mongoose";

const UserSchema = new mongoose.Schema(
  {
    username: { type: String, required: true, unique: true, index: true },
    email: { type: String, unique: true, sparse: true },
    password: { type: String },

    avatar: { type: String, default: "" },
    bio: { type: String, default: "" },
    verified: { type: Boolean, default: false },

    isPrivate: { type: Boolean, default: false },

    followers: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
    following: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
    followRequests: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],

    postsCount: { type: Number, default: 0 },
    followersCount: { type: Number, default: 0 },
    followingCount: { type: Number, default: 0 },
  },
  { timestamps: true }
);

export const User = mongoose.model("User", UserSchema);

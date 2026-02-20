import mongoose from "mongoose";

const UserSchema = new mongoose.Schema(
  {
    username: { type: String, required: true, unique: true, index: true, trim: true },
    email: { type: String, unique: true, sparse: true, lowercase: true, trim: true },
    password: { type: String },

    avatar: { type: String, default: "" },
    bio: { type: String, default: "", maxlength: 150 },
    verified: { type: Boolean, default: false },

    isPrivate: { type: Boolean, default: false },
    banned: { type: Boolean, default: false },
    role: { type: String, enum: ["user", "admin"], default: "user" },

    lastSeen: { type: Date, default: null },

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

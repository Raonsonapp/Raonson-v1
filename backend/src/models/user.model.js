import mongoose from "mongoose";

const UserSchema = new mongoose.Schema(
  {
    username: {
      type: String,
      unique: true,
      required: true,
      index: true,
    },

    email: {
      type: String,
      unique: true,
      sparse: true,
    },

    avatar: {
      type: String,
      default: "",
    },

    bio: {
      type: String,
      default: "",
      maxlength: 150,
    },

    verified: {
      type: Boolean,
      default: false,
      index: true,
    },

    followersCount: { type: Number, default: 0 },
    followingCount: { type: Number, default: 0 },
    postsCount: { type: Number, default: 0 },

    // 🔒 auth
    passwordHash: String,
  },
  { timestamps: true }
);

export const User = mongoose.model("User", UserSchema);

import mongoose from "mongoose";

const PostSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User", index: true },
    caption: { type: String, default: "" },

    media: [
      {
        url: String,
        type: { type: String, enum: ["image", "video"] },
      },
    ],

    likes: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
    saves: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
  },
  { timestamps: true }
);

// 🔥 FEED PERFORMANCE
PostSchema.index({ user: 1, createdAt: -1 });

export const Post = mongoose.model("Post", PostSchema);

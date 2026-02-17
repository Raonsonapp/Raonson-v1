import mongoose from "mongoose";

const LikeSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    targetId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
    },

    targetType: {
      type: String,
      enum: ["post", "comment", "story", "reel"],
      required: true,
    },
  },
  { timestamps: true }
);

LikeSchema.index({ user: 1, targetId: 1, targetType: 1 }, { unique: true });

export const Like = mongoose.model("Like", LikeSchema);

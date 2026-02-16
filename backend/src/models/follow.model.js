import mongoose from "mongoose";

const FollowSchema = new mongoose.Schema(
  {
    follower: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      index: true,
      required: true,
    },
    following: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      index: true,
      required: true,
    },
  },
  { timestamps: true }
);

// ❗ як нафар як нафарро 1 бор follow кунад
FollowSchema.index({ follower: 1, following: 1 }, { unique: true });

export const Follow = mongoose.model("Follow", FollowSchema);

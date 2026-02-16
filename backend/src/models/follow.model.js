import mongoose from "mongoose";

const FollowSchema = new mongoose.Schema(
  {
    from: { type: mongoose.Schema.Types.ObjectId, ref: "User", index: true },
    to: { type: mongoose.Schema.Types.ObjectId, ref: "User", index: true },
    status: {
      type: String,
      enum: ["following", "requested"],
      default: "following",
    },
  },
  { timestamps: true }
);

export const Follow = mongoose.model("Follow", FollowSchema);

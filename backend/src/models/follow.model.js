import mongoose from "mongoose";

const followSchema = new mongoose.Schema(
  {
    from: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    to: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
  },
  { timestamps: true }
);

// prevent duplicate follows
followSchema.index({ from: 1, to: 1 }, { unique: true });

export const Follow = mongoose.model("Follow", followSchema);

import mongoose from "mongoose";

const followSchema = new mongoose.Schema(
  {
    followerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    followingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
  },
  { timestamps: true }
);

// як корбар ду бор follow карда наметавонад
followSchema.index(
  { followerId: 1, followingId: 1 },
  { unique: true }
);

export default mongoose.model("Follow", followSchema);

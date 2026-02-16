import mongoose from "mongoose";

const ReelSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    videoUrl: { type: String, required: true },
    caption: { type: String, default: "" },

    views: {
      type: Number,
      default: 0,
      index: true,
    },

    likedBy: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],

    savedBy: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],

    shares: { type: Number, default: 0 },

    // 🔥 algorithm score
    score: {
      type: Number,
      default: 0,
      index: true,
    },
  },
  { timestamps: true }
);

export const Reel = mongoose.model("Reel", ReelSchema);

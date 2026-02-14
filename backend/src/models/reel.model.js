import mongoose from "mongoose";

const reelSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    videoUrl: { type: String, required: true },
    caption: { type: String },

    // 🔥 LIKE SYSTEM
    likes: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],

    likesCount: { type: Number, default: 0 },
    viewsCount: { type: Number, default: 0 },
  },
  { timestamps: true }
);

export default mongoose.model("Reel", reelSchema);

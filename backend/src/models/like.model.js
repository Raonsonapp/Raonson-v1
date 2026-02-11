import mongoose from "mongoose";

const likeSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    postId: { type: mongoose.Schema.Types.ObjectId, ref: "Post", required: true },
  },
  { timestamps: true }
);

likeSchema.index({ userId: 1, postId: 1 }, { unique: true });

export default mongoose.model("Like", likeSchema);

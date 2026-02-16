import mongoose from "mongoose";

const StorySchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    mediaUrl: { type: String, required: true },
    mediaType: {
      type: String,
      enum: ["image", "video"],
      required: true,
    },

    views: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],

    likes: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],

    expiresAt: {
      type: Date,
      index: { expires: 0 }, // ⏱ auto delete
    },
  },
  { timestamps: true }
);

// 24h TTL
StorySchema.pre("save", function (next) {
  if (!this.expiresAt) {
    this.expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);
  }
  next();
});

export const Story = mongoose.model("Story", StorySchema);

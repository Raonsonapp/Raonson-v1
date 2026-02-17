import mongoose from "mongoose";

const NotificationSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    fromUser: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },

    type: {
      type: String,
      enum: [
        "like",
        "comment",
        "follow",
        "follow_request",
        "reel_like",
        "story_view",
        "message",
      ],
      required: true,
    },

    targetId: {
      type: mongoose.Schema.Types.ObjectId,
    },

    read: { type: Boolean, default: false },
  },
  { timestamps: true }
);

export const Notification = mongoose.model(
  "Notification",
  NotificationSchema
);

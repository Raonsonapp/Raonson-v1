import mongoose from "mongoose";

const MessageSchema = new mongoose.Schema(
  {
    chatId: { type: String, required: true },

    sender: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    receiver: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    text: { type: String, default: "" },
    mediaUrl: { type: String, default: "" },

    read: { type: Boolean, default: false },
  },
  { timestamps: true }
);

export const Message = mongoose.model("Message", MessageSchema);

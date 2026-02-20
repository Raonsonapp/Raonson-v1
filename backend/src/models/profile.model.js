import mongoose from "mongoose";

const ProfileSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      unique: true,
      required: true,
    },

    website: { type: String, default: "" },
    location: { type: String, default: "" },
    birthday: { type: Date },

    highlights: [{ type: String }],
  },
  { timestamps: true }
);

export const Profile = mongoose.model("Profile", ProfileSchema);

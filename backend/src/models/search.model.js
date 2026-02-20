import mongoose from "mongoose";

const SearchSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    query: String,
    type: { type: String, enum: ["user", "hashtag"] },
  },
  { timestamps: true }
);

export const Search = mongoose.model("Search", SearchSchema);

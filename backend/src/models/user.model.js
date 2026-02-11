import mongoose from "mongoose";

const userSchema = new mongoose.Schema(
  {
    phone: { type: String, unique: true, required: true },
    email: { type: String },
    password: { type: String },
    verified: { type: Boolean, default: false },
  },
  { timestamps: true }
);

export default mongoose.model("User", userSchema);

import User from "../models/User.js";
import jwt from "jsonwebtoken";

const OTP_TTL = 5 * 60 * 1000; // 5 minutes

export const sendOtp = async (req, res) => {
  const { phone } = req.body;
  const code = Math.floor(100000 + Math.random() * 900000).toString();

  let user = await User.findOne({ phone });
  if (!user) user = await User.create({ phone });

  user.otpCode = code;
  user.otpExpire = new Date(Date.now() + OTP_TTL);
  await user.save();

  console.log("OTP:", code); // 👉 ҳоло mock, баъд SMS

  res.json({ ok: true });
};

export const verifyOtp = async (req, res) => {
  const { phone, code } = req.body;

  const user = await User.findOne({ phone });
  if (!user) return res.status(400).json({ error: "User not found" });

  if (
    user.otpCode !== code ||
    !user.otpExpire ||
    user.otpExpire < new Date()
  ) {
    return res.status(400).json({ error: "Invalid or expired code" });
  }

  const tempToken = jwt.sign(
    { phone: user.phone },
    process.env.JWT_SECRET,
    { expiresIn: "5m" }
  );

  res.json({ tempToken });
};

export const verifyGmail = async (req, res) => {
  const { email } = req.body;
  const { phone } = req.user;

  const user = await User.findOne({ phone });
  if (!user) return res.status(400).json({ error: "User not found" });

  user.email = email;
  user.verified = true;
  user.otpCode = null;
  user.otpExpire = null;
  await user.save();

  const token = jwt.sign(
    { id: user._id },
    process.env.JWT_SECRET,
    { expiresIn: "7d" }
  );

  res.json({ token, userId: user._id });
};

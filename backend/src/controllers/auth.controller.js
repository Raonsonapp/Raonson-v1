import jwt from "jsonwebtoken";
import User from "../models/user.model.js";

const OTP_EXPIRE_MINUTES = 5;

// helper
const generateOtp = () =>
  Math.floor(100000 + Math.random() * 900000).toString();

// ============================
// SEND OTP (PHONE OR EMAIL)
// ============================
export const sendOtp = async (req, res) => {
  const { phone, email } = req.body;

  if (!phone && !email) {
    return res.status(400).json({ error: "phone or email required" });
  }

  let user = await User.findOne({
    ...(phone ? { phone } : { email }),
  });

  if (!user) {
    user = await User.create({
      phone,
      email,
    });
  }

  const otp = generateOtp();

  user.otpCode = otp;
  user.otpExpire = new Date(Date.now() + OTP_EXPIRE_MINUTES * 60 * 1000);
  await user.save();

  // MVP: OTP-ро бармегардонем (баъд SMS/Email)
  console.log("OTP:", otp);

  res.json({
    success: true,
    otp, // ❗️MVP ONLY
  });
};

// ============================
// VERIFY OTP
// ============================
export const verifyOtp = async (req, res) => {
  const { phone, email, otp } = req.body;

  if ((!phone && !email) || !otp) {
    return res.status(400).json({ error: "invalid request" });
  }

  const user = await User.findOne({
    ...(phone ? { phone } : { email }),
  });

  if (!user || user.otpCode !== otp) {
    return res.status(400).json({ error: "invalid otp" });
  }

  if (user.otpExpire < new Date()) {
    return res.status(400).json({ error: "otp expired" });
  }

  user.verified = true;
  user.otpCode = null;
  user.otpExpire = null;
  await user.save();

  const token = jwt.sign(
    { id: user._id },
    process.env.JWT_SECRET || "dev-secret",
    { expiresIn: "30d" }
  );

  res.json({
    token,
    user: {
      id: user._id,
      phone: user.phone,
      email: user.email,
    },
  });
};

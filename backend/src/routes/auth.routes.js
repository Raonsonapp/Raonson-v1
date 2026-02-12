import jwt from "jsonwebtoken";

/**
 * In-memory users (MVP)
 * later replaced by MongoDB
 */
const users = {};

const OTP_TTL = 5 * 60 * 1000; // 5 minutes

// STEP 1 — SEND OTP
export const sendOtp = async (req, res) => {
  const { phone } = req.body;
  if (!phone) {
    return res.status(400).json({ error: "Phone required" });
  }

  const code = Math.floor(100000 + Math.random() * 900000).toString();

  users[phone] = {
    phone,
    otpCode: code,
    otpExpire: Date.now() + OTP_TTL,
    verified: false,
  };

  console.log("OTP (mock):", code);

  res.json({ ok: true });
};

// STEP 2 — VERIFY OTP
export const verifyOtp = async (req, res) => {
  const { phone, code } = req.body;

  const user = users[phone];
  if (!user) {
    return res.status(400).json({ error: "User not found" });
  }

  if (
    user.otpCode !== code ||
    user.otpExpire < Date.now()
  ) {
    return res.status(400).json({ error: "Invalid or expired code" });
  }

  const tempToken = jwt.sign(
    { phone },
    process.env.JWT_SECRET || "dev-secret",
    { expiresIn: "5m" }
  );

  res.json({ tempToken });
};

// STEP 3 — VERIFY GMAIL
export const verifyGmail = async (req, res) => {
  const { email } = req.body;
  const { phone } = req.user;

  const user = users[phone];
  if (!user) {
    return res.status(400).json({ error: "User not found" });
  }

  user.email = email;
  user.verified = true;
  user.otpCode = null;
  user.otpExpire = null;

  const token = jwt.sign(
    { phone },
    process.env.JWT_SECRET || "dev-secret",
    { expiresIn: "7d" }
  );

  res.json({
    token,
    user: {
      phone,
      email,
    },
  });
};

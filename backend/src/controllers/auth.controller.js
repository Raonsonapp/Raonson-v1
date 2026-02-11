import User from "../models/user.model.js";

// STEP 1
export const registerStep1 = async (req, res) => {
  const { phone } = req.body;

  if (!phone) return res.status(400).json({ error: "Phone required" });
  if (!(phone.startsWith("+992") || phone.startsWith("+7"))) {
    return res.status(400).json({ error: "Only +992 or +7 allowed" });
  }

  let user = await User.findOne({ phone });
  if (!user) {
    user = await User.create({ phone });
  }

  return res.json({ message: "Step 1 OK", phone });
};

// STEP 2 (mock code)
export const registerStep2 = async (req, res) => {
  const { phone, code } = req.body;

  if (!phone || !code) {
    return res.status(400).json({ error: "Phone & code required" });
  }

  const user = await User.findOne({ phone });
  if (!user) return res.status(404).json({ error: "User not found" });

  user.verified = true;
  await user.save();

  return res.json({ message: "Verified" });
};

// LOGIN (mock password)
export const login = async (req, res) => {
  const { phone, password } = req.body;

  const user = await User.findOne({ phone, verified: true });
  if (!user) return res.status(401).json({ error: "Unauthorized" });

  // V1: mock token
  return res.json({
    token: `token_${user._id}`,
  });
};

export const login = (req, res) => {
  const { phone, email } = req.body;

  if (!phone || !email) {
    return res.status(400).json({ error: "phone and email required" });
  }

  res.json({
    message: "Login OK (demo)",
    user: {
      id: 1,
      phone,
      email
    }
  });
};

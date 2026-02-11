export const getProfile = (req, res) => {
  return res.json({
    id: req.user.id,
    phone: req.user.phone,
    email: req.user.email,
    username: "raonson_user",
    verified: false,
  });
};

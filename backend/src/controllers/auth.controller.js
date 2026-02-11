export const registerStep1 = (req, res) => {
  const { phone } = req.body;

  if (!phone) {
    return res.status(400).json({ error: "Phone is required" });
  }

  // Фақат +992 ва +7 иҷозат
  if (!(phone.startsWith("+992") || phone.startsWith("+7"))) {
    return res.status(400).json({
      error: "Only Tajikistan (+992) and Russia (+7) numbers allowed",
    });
  }

  // V1: ҳоло SMS нест, фақат тасдиқ
  return res.json({
    message: "Step 1 OK",
    phone,
  });
};

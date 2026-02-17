export async function uploadMedia(req, res) {
  res.json({
    url: req.file.path,
    type: req.file.mimetype,
  });
}

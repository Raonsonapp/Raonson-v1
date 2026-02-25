import fs from "fs";
import path from "path";

async function getCloudinary() {
  const { CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET } = process.env;
  if (!CLOUDINARY_CLOUD_NAME || !CLOUDINARY_API_KEY || !CLOUDINARY_API_SECRET) {
    return null;
  }
  const { v2: cloudinary } = await import("cloudinary");
  cloudinary.config({
    cloud_name: CLOUDINARY_CLOUD_NAME,
    api_key: CLOUDINARY_API_KEY,
    api_secret: CLOUDINARY_API_SECRET,
  });
  return cloudinary;
}

export const uploadFile = async (req, res) => {
  if (!req.file) {
    console.error("Upload: no file in request");
    return res.status(400).json({ error: "No file uploaded" });
  }

  console.log("Upload file:", req.file.filename, "size:", req.file.size);

  try {
    const cloudinary = await getCloudinary();

    if (cloudinary) {
      console.log("Using Cloudinary...");
      const result = await cloudinary.uploader.upload(req.file.path, {
        resource_type: "auto",
        folder: "raonson",
      });
      fs.unlink(req.file.path, () => {});
      console.log("Cloudinary success:", result.secure_url);
      return res.json({ url: result.secure_url });
    } else {
      // No Cloudinary - serve from local disk
      const base = (process.env.BASE_URL || "https://raonson-v1.onrender.com").replace(/\/$/, "");
      const url = `${base}/uploads/${req.file.filename}`;
      console.log("Local upload URL:", url);
      return res.json({ url });
    }
  } catch (err) {
    console.error("Upload error:", err.message);
    // Fallback to local if cloudinary fails
    if (req.file && req.file.filename) {
      const base = (process.env.BASE_URL || "https://raonson-v1.onrender.com").replace(/\/$/, "");
      const url = `${base}/uploads/${req.file.filename}`;
      return res.json({ url });
    }
    return res.status(500).json({ error: "Upload failed: " + err.message });
  }
};

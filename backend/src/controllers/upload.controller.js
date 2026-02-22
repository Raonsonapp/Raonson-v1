import { v2 as cloudinary } from "cloudinary";
import fs from "fs";

// Configure cloudinary from env vars
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

export const uploadFile = async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: "No file uploaded" });
  }

  // Check if Cloudinary is configured
  const hasCloudinary =
    process.env.CLOUDINARY_CLOUD_NAME &&
    process.env.CLOUDINARY_API_KEY &&
    process.env.CLOUDINARY_API_SECRET;

  if (!hasCloudinary) {
    // Fallback: return local URL (works only on paid Render with persistent disk)
    const url = `${process.env.BASE_URL || "https://raonson-v1.onrender.com"}/uploads/${req.file.filename}`;
    return res.json({ url });
  }

  try {
    // Upload to Cloudinary
    const result = await cloudinary.uploader.upload(req.file.path, {
      resource_type: "auto", // handles images and videos
      folder: "raonson",
    });

    // Delete local temp file after upload
    fs.unlink(req.file.path, () => {});

    res.json({ url: result.secure_url });
  } catch (err) {
    console.error("Cloudinary upload error:", err);
    // Fallback to local URL
    const url = `${process.env.BASE_URL || "https://raonson-v1.onrender.com"}/uploads/${req.file.filename}`;
    res.json({ url });
  }
};

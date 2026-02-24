import multer from "multer";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { dirname } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Lazy-load cloudinary only if configured
async function getCloudinary() {
  const { CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET } = process.env;
  if (!CLOUDINARY_CLOUD_NAME || !CLOUDINARY_API_KEY || !CLOUDINARY_API_SECRET) return null;
  const { v2: cloudinary } = await import("cloudinary");
  cloudinary.config({ cloud_name: CLOUDINARY_CLOUD_NAME, api_key: CLOUDINARY_API_KEY, api_secret: CLOUDINARY_API_SECRET });
  return cloudinary;
}

export const uploadFile = async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: "No file uploaded" });
  }

  try {
    const cloudinary = await getCloudinary();

    if (cloudinary) {
      // Upload to Cloudinary
      const result = await cloudinary.uploader.upload(req.file.path, {
        resource_type: "auto",
        folder: "raonson",
      });
      // Clean up local file
      fs.unlink(req.file.path, () => {});
      return res.json({ url: result.secure_url });
    } else {
      // No Cloudinary - serve local file
      const base = process.env.BASE_URL || "https://raonson-v1.onrender.com";
      return res.json({ url: `${base}/uploads/${req.file.filename}` });
    }
  } catch (err) {
    console.error("Upload error:", err);
    // Fallback
    const base = process.env.BASE_URL || "https://raonson-v1.onrender.com";
    return res.json({ url: `${base}/uploads/${req.file.filename}` });
  }
};

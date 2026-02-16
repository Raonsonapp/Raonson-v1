import multer from "multer";
import path from "path";
import fs from "fs";

const uploadDir = "uploads/stories";
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (_, __, cb) => cb(null, uploadDir),
  filename: (_, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, Date.now() + ext);
  },
});

export const storyUpload = multer({
  storage,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB
});

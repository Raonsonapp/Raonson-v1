import multer from "multer";
import path from "path";

const storage = multer.diskStorage({
  destination: "uploads/",
  filename: (_, file, cb) => {
    const unique =
      Date.now() + "-" + Math.round(Math.random() * 1e9);
    cb(null, unique + path.extname(file.originalname));
  },
});

function fileFilter(_, file, cb) {
  const allowed = ["image/", "video/"];
  if (allowed.some(type => file.mimetype.startsWith(type))) {
    cb(null, true);
  } else {
    cb(new Error("Unsupported media type"), false);
  }
}

const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB
});

// ⬇️ ИН ҶО МУҲИМ АСТ
export const uploadMiddleware = upload.single("file");

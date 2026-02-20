const IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp"];
const VIDEO_TYPES = ["video/mp4", "video/quicktime"];

export function isImage(mime) {
  return IMAGE_TYPES.includes(mime);
}

export function isVideo(mime) {
  return VIDEO_TYPES.includes(mime);
}

export function validateFile(file, maxSizeMB = 50) {
  if (!file) throw new Error("File missing");

  const sizeMB = file.size / (1024 * 1024);
  if (sizeMB > maxSizeMB) {
    throw new Error("File too large");
  }

  if (!isImage(file.mimetype) && !isVideo(file.mimetype)) {
    throw new Error("Unsupported file type");
  }

  return true;
}

export function extractExtension(filename) {
  return filename.split(".").pop().toLowerCase();
}

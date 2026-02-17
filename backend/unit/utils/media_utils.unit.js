describe("UTILS / MEDIA", () => {
  function detectMediaType(filename) {
    const ext = filename.split(".").pop().toLowerCase();
    if (["jpg", "jpeg", "png", "webp"].includes(ext)) return "image";
    if (["mp4", "mov", "avi"].includes(ext)) return "video";
    return "unknown";
  }

  function isValidMediaSize(sizeMb, limitMb) {
    return sizeMb <= limitMb;
  }

  it("should detect image type", () => {
    expect(detectMediaType("photo.jpg")).toBe("image");
  });

  it("should detect video type", () => {
    expect(detectMediaType("clip.mp4")).toBe("video");
  });

  it("should detect unknown type", () => {
    expect(detectMediaType("file.txt")).toBe("unknown");
  });

  it("should validate media size", () => {
    expect(isValidMediaSize(10, 20)).toBe(true);
    expect(isValidMediaSize(25, 20)).toBe(false);
  });
});

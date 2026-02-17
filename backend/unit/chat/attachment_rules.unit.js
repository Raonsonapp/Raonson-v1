describe("CHAT / ATTACHMENT RULES", () => {
  function validateAttachment({ type, sizeMB }) {
    const limits = {
      image: 10,
      video: 50,
      audio: 20,
      file: 25,
    };

    if (!limits[type]) return false;
    return sizeMB <= limits[type];
  }

  it("should allow image under size limit", () => {
    expect(validateAttachment({ type: "image", sizeMB: 5 })).toBe(true);
  });

  it("should reject oversized video", () => {
    expect(validateAttachment({ type: "video", sizeMB: 80 })).toBe(false);
  });

  it("should reject unknown attachment type", () => {
    expect(validateAttachment({ type: "exe", sizeMB: 1 })).toBe(false);
  });
});

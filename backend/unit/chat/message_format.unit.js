describe("CHAT / MESSAGE FORMAT", () => {
  function formatMessage({ text, attachments }) {
    if (!text && (!attachments || attachments.length === 0)) {
      throw new Error("Message must contain text or attachment");
    }

    return {
      text: text || "",
      attachments: attachments || [],
      createdAt: new Date(),
    };
  }

  it("should allow text-only message", () => {
    const msg = formatMessage({ text: "Hello", attachments: [] });
    expect(msg.text).toBe("Hello");
  });

  it("should allow attachment-only message", () => {
    const msg = formatMessage({
      text: "",
      attachments: [{ type: "image", url: "x.jpg" }],
    });
    expect(msg.attachments.length).toBe(1);
  });

  it("should reject empty message", () => {
    expect(() =>
      formatMessage({ text: "", attachments: [] })
    ).toThrow();
  });
});

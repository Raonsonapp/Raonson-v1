describe("NOTIFICATIONS / RULES", () => {
  function shouldNotify({ actorId, targetUserId, muted, blocked }) {
    if (actorId === targetUserId) return false; // no self-notify
    if (blocked) return false;
    if (muted) return false;
    return true;
  }

  it("should not notify user about their own action", () => {
    const result = shouldNotify({
      actorId: "u1",
      targetUserId: "u1",
      muted: false,
      blocked: false,
    });
    expect(result).toBe(false);
  });

  it("should not notify if target muted actor", () => {
    const result = shouldNotify({
      actorId: "u1",
      targetUserId: "u2",
      muted: true,
      blocked: false,
    });
    expect(result).toBe(false);
  });

  it("should not notify if actor is blocked", () => {
    const result = shouldNotify({
      actorId: "u1",
      targetUserId: "u2",
      muted: false,
      blocked: true,
    });
    expect(result).toBe(false);
  });

  it("should notify when rules are satisfied", () => {
    const result = shouldNotify({
      actorId: "u1",
      targetUserId: "u2",
      muted: false,
      blocked: false,
    });
    expect(result).toBe(true);
  });
});

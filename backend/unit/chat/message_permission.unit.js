describe("CHAT / MESSAGE PERMISSIONS", () => {
  function canSendMessage({ isBlocked, isFollowing, isPrivate }) {
    if (isBlocked) return false;
    if (!isPrivate) return true;
    return isFollowing;
  }

  it("should block sending if user is blocked", () => {
    const result = canSendMessage({
      isBlocked: true,
      isFollowing: true,
      isPrivate: false,
    });
    expect(result).toBe(false);
  });

  it("should allow message to public account", () => {
    const result = canSendMessage({
      isBlocked: false,
      isFollowing: false,
      isPrivate: false,
    });
    expect(result).toBe(true);
  });

  it("should allow message to private account only if following", () => {
    const allowed = canSendMessage({
      isBlocked: false,
      isFollowing: true,
      isPrivate: true,
    });

    const denied = canSendMessage({
      isBlocked: false,
      isFollowing: false,
      isPrivate: true,
    });

    expect(allowed).toBe(true);
    expect(denied).toBe(false);
  });
});

describe("USERS / FOLLOW LOGIC", () => {
  function follow(user, target) {
    if (!user.following.includes(target)) {
      user.following.push(target);
      target.followers.push(user.id);
    }
  }

  it("should follow user correctly", () => {
    const user = { id: "u1", following: [] };
    const target = { id: "u2", followers: [] };

    follow(user, target);

    expect(user.following).toContain(target);
    expect(target.followers).toContain(user.id);
  });

  it("should not duplicate follow", () => {
    const user = { id: "u1", following: [] };
    const target = { id: "u2", followers: [] };

    follow(user, target);
    follow(user, target);

    expect(user.following.length).toBe(1);
    expect(target.followers.length).toBe(1);
  });
});

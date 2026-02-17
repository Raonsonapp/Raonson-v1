describe("USERS / BLOCK LOGIC", () => {
  function block(user, target) {
    user.blocked.push(target.id);
    user.following = user.following.filter((id) => id !== target.id);
    user.followers = user.followers.filter((id) => id !== target.id);
  }

  it("should block user and remove follow relations", () => {
    const user = {
      id: "u1",
      following: ["u2"],
      followers: ["u2"],
      blocked: [],
    };
    const target = { id: "u2" };

    block(user, target);

    expect(user.blocked).toContain("u2");
    expect(user.following).not.toContain("u2");
    expect(user.followers).not.toContain("u2");
  });
});

describe("NOTIFICATIONS / DEDUPLICATION", () => {
  function deduplicate(existing, incoming) {
    const key = (n) => `${n.type}:${n.actor}:${n.target}:${n.entityId}`;
    const seen = new Set(existing.map(key));
    return incoming.filter((n) => !seen.has(key(n)));
  }

  it("should remove duplicate notifications with same signature", () => {
    const existing = [
      { type: "like", actor: "u1", target: "u2", entityId: "p1" },
    ];

    const incoming = [
      { type: "like", actor: "u1", target: "u2", entityId: "p1" },
      { type: "comment", actor: "u1", target: "u2", entityId: "p1" },
    ];

    const result = deduplicate(existing, incoming);
    expect(result.length).toBe(1);
    expect(result[0].type).toBe("comment");
  });

  it("should keep notifications with different entityId", () => {
    const existing = [
      { type: "like", actor: "u1", target: "u2", entityId: "p1" },
    ];

    const incoming = [
      { type: "like", actor: "u1", target: "u2", entityId: "p2" },
    ];

    const result = deduplicate(existing, incoming);
    expect(result.length).toBe(1);
  });

  it("should keep notifications with different actor", () => {
    const existing = [
      { type: "like", actor: "u1", target: "u2", entityId: "p1" },
    ];

    const incoming = [
      { type: "like", actor: "u3", target: "u2", entityId: "p1" },
    ];

    const result = deduplicate(existing, incoming);
    expect(result.length).toBe(1);
  });
});

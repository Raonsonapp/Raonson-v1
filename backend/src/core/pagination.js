export function getPagination(query) {
  const page = Math.max(parseInt(query.page || "1", 10), 1);
  const limit = Math.min(parseInt(query.limit || "20", 10), 100);
  const skip = (page - 1) * limit;

  return { page, limit, skip };
}

export function slugify(text) {
  return text
    .toString()
    .toLowerCase()
    .trim()
    .replace(/[^\w\s-]/g, "")
    .replace(/[\s_-]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

export function uniqueSlug(base, existsFn) {
  let slug = slugify(base);
  let counter = 1;

  while (existsFn(slug)) {
    slug = `${slug}-${counter++}`;
  }

  return slug;
}

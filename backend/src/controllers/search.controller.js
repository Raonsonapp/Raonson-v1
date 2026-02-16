import {
  searchAll,
  getRecentSearches,
  clearRecentSearches,
} from "../services/search.service.js";

export async function search(req, res, next) {
  try {
    const { q } = req.query;

    const result = await searchAll({
      userId: req.user._id,
      q,
    });

    res.json(result);
  } catch (e) {
    next(e);
  }
}

export async function recent(req, res, next) {
  try {
    const items = await getRecentSearches(req.user._id);
    res.json(items);
  } catch (e) {
    next(e);
  }
}

export async function clear(req, res, next) {
  try {
    await clearRecentSearches(req.user._id);
    res.json({ ok: true });
  } catch (e) {
    next(e);
  }
}

export function validateMiddleware(requiredFields = []) {
  return (req, res, next) => {
    const missing = [];

    for (const field of requiredFields) {
      if (
        req.body[field] === undefined ||
        req.body[field] === null
      ) {
        missing.push(field);
      }
    }

    if (missing.length > 0) {
      return res.status(400).json({
        error: "Validation failed",
        missingFields: missing,
      });
    }

    next();
  };
}

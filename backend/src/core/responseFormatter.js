export function success(res, data, meta = {}) {
  res.json({
    success: true,
    data,
    meta,
  });
}

export function failure(res, status, message) {
  res.status(status).json({
    success: false,
    error: message,
  });
}

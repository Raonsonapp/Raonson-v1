import jwt from "jsonwebtoken";

const {
  JWT_ACCESS_SECRET,
  JWT_REFRESH_SECRET,
  JWT_ACCESS_EXPIRES = "15m",
  JWT_REFRESH_EXPIRES = "30d",
} = process.env;

if (!JWT_ACCESS_SECRET || !JWT_REFRESH_SECRET) {
  throw new Error("JWT secrets are not defined");
}

export function signAccessToken(payload) {
  return jwt.sign(payload, JWT_ACCESS_SECRET, {
    expiresIn: JWT_ACCESS_EXPIRES,
  });
}

export function signRefreshToken(payload) {
  return jwt.sign(payload, JWT_REFRESH_SECRET, {
    expiresIn: JWT_REFRESH_EXPIRES,
  });
}

export function verifyAccessToken(token) {
  return jwt.verify(token, JWT_ACCESS_SECRET);
}

export function verifyRefreshToken(token) {
  return jwt.verify(token, JWT_REFRESH_SECRET);
                  }

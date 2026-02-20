import crypto from "crypto";

export function randomToken(length = 48) {
  return crypto.randomBytes(length).toString("hex");
}

export function hash(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

export function compareHash(raw, hashed) {
  return hash(raw) === hashed;
}

export function signHmac(data, secret) {
  return crypto
    .createHmac("sha256", secret)
    .update(data)
    .digest("hex");
}

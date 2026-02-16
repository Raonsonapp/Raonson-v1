import { registerUser, loginUser } from "../services/auth.service.js";
import { formatResponse } from "../core/responseFormatter.js";

export async function register(req, res, next) {
  try {
    const user = await registerUser(req.body);
    res.json(formatResponse(true, "Registered", user));
  } catch (e) {
    next(e);
  }
}

export async function login(req, res, next) {
  try {
    const { user, token } = await loginUser(req.body);
    res.json(formatResponse(true, "Logged in", { user, token }));
  } catch (e) {
    next(e);
  }
}

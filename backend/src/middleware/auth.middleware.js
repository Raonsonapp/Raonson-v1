export const authMiddleware = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    return res.status(401).json({ error: "No token provided" });
  }

  const token = authHeader.replace("Bearer ", "");

  // V1: ҳоло фақат месанҷем, ки token ҳаст ё не
  if (!token || token.length < 10) {
    return res.status(401).json({ error: "Invalid token" });
  }

  // mock user (баъд аз DB меояд)
  req.user = {
    id: "user_1",
    phone: "+992928826371",
    email: "test@gmail.com",
  };

  next();
};

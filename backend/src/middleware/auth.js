import { getUserById, verifyToken } from '../services/auth.service.js';
import { asyncHandler, unauthorized } from '../utils/http-error.js';

/** Extracts "Bearer <token>", verifies it and attaches the fresh DB user to req.user. */
export const requireAuth = asyncHandler(async (req, _res, next) => {
  const header = req.headers.authorization ?? '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) throw unauthorized();
  const payload = verifyToken(token);
  const user = await getUserById(payload.sub);
  if (!user) throw unauthorized('User no longer exists');
  req.user = user;
  next();
});

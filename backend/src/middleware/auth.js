import { getUserById, userBlocked, verifyToken } from '../services/auth.service.js';
import { asyncHandler, forbidden, unauthorized } from '../utils/http-error.js';
import { toBool } from '../utils/validators.js';

/** Extracts "Bearer <token>", verifies it and attaches the fresh DB user to req.user. */
export const requireAuth = asyncHandler(async (req, _res, next) => {
  const header = req.headers.authorization ?? '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) throw unauthorized();
  const payload = verifyToken(token);
  const user = await getUserById(payload.sub);
  if (!user) throw unauthorized('User no longer exists');
  if (toBool(user.is_blocked)) throw userBlocked();
  req.user = user;
  next();
});

/** Runs after requireAuth: only administrators pass. */
export function requireAdmin(req, _res, next) {
  if (req.user?.role !== 'admin') return next(forbidden('Administrator role required'));
  return next();
}

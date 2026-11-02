import { HttpError } from '../utils/http-error.js';

/**
 * Minimal fixed-window limiter per client IP, kept in memory (one server process).
 * Used for endpoints that create rows without authentication, e.g. demo accounts.
 */
export function rateLimit({ windowMs, max }) {
  const hits = new Map();
  return (req, _res, next) => {
    const now = Date.now();
    const key = req.ip ?? 'unknown';
    const entry = hits.get(key);
    if (!entry || now - entry.start >= windowMs) {
      hits.set(key, { start: now, count: 1 });
      return next();
    }
    entry.count += 1;
    if (entry.count > max) {
      return next(new HttpError(429, 'TOO_MANY_REQUESTS', 'Too many requests, try again later'));
    }
    return next();
  };
}

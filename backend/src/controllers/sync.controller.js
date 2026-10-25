import { synchronize } from '../services/sync.service.js';
import { asyncHandler } from '../utils/http-error.js';

/**
 * POST /api/sync
 * Body: { last_synced_at: number, changes: { <table in SYNC_ORDER>?: rows[] } }
 * Applies client changes (Last-Write-Wins by `updated_at`, single Knex transaction) and
 * returns everything that changed on the server since `last_synced_at`.
 */
export const sync = asyncHandler(async (req, res) => {
  res.json(await synchronize(req.user, req.body));
});

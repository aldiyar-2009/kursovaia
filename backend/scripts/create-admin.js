/**
 * Creates an administrator or promotes an existing user (and unblocks it):
 *   npm run create-admin -- admin@example.com secret123 "Admin Name"
 * Touches only that one user, so it is safe to run against the production DB.
 */
import bcrypt from 'bcryptjs';
import { closeDb, db } from '../src/config/db.js';
import { env } from '../src/config/env.js';
import { newId } from '../src/utils/validators.js';

async function main() {
  const [emailArg, password, name = 'Administrator'] = process.argv.slice(2);
  if (!emailArg || !password || password.length < 6) {
    console.error('Usage: npm run create-admin -- <email> <password (6+ chars)> [name]');
    process.exitCode = 1;
    return;
  }
  await db.migrate.latest();
  const email = emailArg.trim().toLowerCase();
  const now = Date.now();
  const passwordHash = await bcrypt.hash(password, env.bcryptRounds);
  const existing = await db('users').where({ email }).first();
  if (existing) {
    await db('users').where({ id: existing.id })
      .update({ role: 'admin', is_blocked: false, password_hash: passwordHash, updated_at: now });
    console.log(`[admin] ${email} is now an administrator (password updated)`);
  } else {
    await db('users').insert({
      id: newId(), email, password_hash: passwordHash, name, role: 'admin',
      is_blocked: false, is_demo: false, group_id: null, created_at: now, updated_at: now,
    });
    console.log(`[admin] created administrator ${email}`);
  }
}

main()
  .catch((err) => {
    console.error('[admin] failed:', err.message);
    process.exitCode = 1;
  })
  .finally(() => closeDb());

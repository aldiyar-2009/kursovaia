/**
 * Loads university events from the Telegram channels in EVENT_SOURCES:
 *   npm run events:refresh [-- <pages>]   (default 5 pages of history)
 * Upserts only the events table.
 */
import { closeDb, db } from '../src/config/db.js';
import { refreshEvents } from '../src/services/events.service.js';

async function main() {
  await db.migrate.latest();
  const n = await refreshEvents({ pages: Number(process.argv[2]) || 5 });
  console.log(`[events] processed events: ${n}`);
}

main()
  .catch((err) => {
    console.error('[events] refresh failed:', err);
    process.exitCode = 1;
  })
  .finally(() => closeDb());

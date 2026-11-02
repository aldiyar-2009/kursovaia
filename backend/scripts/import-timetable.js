/**
 * Re-imports the college timetable from data/timetables/*.xlsx (see manifest.json):
 *   npm run import:timetable
 * Replaces only the timetable_lessons table.
 */
import { closeDb, db } from '../src/config/db.js';
import { importAll } from '../src/services/timetable.service.js';

async function main() {
  await db.migrate.latest();
  const n = await importAll(db);
  console.log(`[timetable] imported lessons: ${n}`);
}

main()
  .catch((err) => {
    console.error('[timetable] import failed:', err);
    process.exitCode = 1;
  })
  .finally(() => closeDb());

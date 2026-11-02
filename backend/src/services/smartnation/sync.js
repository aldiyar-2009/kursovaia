/**
 * Builds a "snapshot" of a student's SmartNation data: profile, grades per subject,
 * statistics and assignments (current + past).
 *
 * Note: load-table returns grades of the WHOLE group — only the student's own
 * (by contingent id) are kept.
 */
const TZ = '+05:00'; // Kazakhstan (single UTC+5 time zone)

/** "3 курс ПМ07-Разработка мобильных приложений(ПО)" -> "ПМ07-Разработка мобильных приложений" */
export function cleanSubjectName(name = '') {
  return String(name ?? '')
    .replace(/^\s*\d\s*курс\s*/i, '')
    .replace(/\s*\((ПО|БҚ|ВТ)\)\s*$/i, '')
    .trim();
}

/** "25.09.2026 23:00" | "18.09.2026" -> ISO string in the college time zone. */
export function parseSnDate(s) {
  const m = String(s || '').match(/(\d{2})\.(\d{2})\.(\d{4})(?:\s+(\d{2}):(\d{2}))?/);
  if (!m) return null;
  const [, d, mo, y, h = '23', mi = '59'] = m;
  return new Date(`${y}-${mo}-${d}T${h}:${mi}:00${TZ}`).toISOString();
}

/** "18.09.2026" -> "2026-09-18" */
export function parseSnDay(s) {
  const m = String(s || '').match(/(\d{2})\.(\d{2})\.(\d{4})/);
  return m ? `${m[3]}-${m[2]}-${m[1]}` : null;
}

// Statuses after which the student has nothing left to do.
const DONE_STATUSES = ['Проверено', 'На проверке', 'Выполнено'];

/** Runs `fn` over items with limited concurrency (do not hammer the portal). */
async function mapLimit(items, limit, fn) {
  const out = new Array(items.length);
  let i = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (i < items.length) {
      const idx = i;
      i += 1;
      // eslint-disable-next-line no-await-in-loop
      out[idx] = await fn(items[idx], idx);
    }
  });
  await Promise.all(workers);
  return out;
}

const round1 = (n) => Math.round(n * 10) / 10;

async function collectSubject(client, journal) {
  const contingent = await client.getContingent(journal.id);
  const me = (contingent.students || []).find((s) => s.isCurrent) || contingent.students?.[0];
  const subject = {
    id: String(journal.id),
    name: cleanSubjectName(journal.name),
    kind: journal.type || null, // «Теоретическое обучение» / «Производственное обучение»
    teacher: journal.educators ? String(journal.educators).replace(/<[^>]+>/g, ', ') : null,
    grades: [],
    average: null,
    absences: 0,
  };
  if (!me) return subject;

  const refs = await client.getRefs(journal.id);
  const months = (refs.yearMonths || []).map((m) => m.id);

  for (const ym of months) {
    // eslint-disable-next-line no-await-in-loop
    const table = await client.getLoadTable(journal.id, ym);
    const year = String(ym).split('/')[1];
    for (const day of table.days || []) {
      const p = day.points?.[me.id];
      if (!p || (p.point == null && !p.absented)) continue;
      const [dd, mm] = String(day.label || '').split('.');
      subject.grades.push({
        date: dd && mm && year ? `${year}-${mm}-${dd}` : null,
        value: p.point == null ? null : Number(p.point),
        label: p.label,
        absent: Boolean(p.absented),
        failed: Boolean(p.failed),
        theme: day.theme || null,
        is_exam: Boolean(day.isExam),
      });
    }
  }

  subject.grades.sort((a, b) => String(a.date).localeCompare(String(b.date)));
  const values = subject.grades.filter((g) => g.value != null).map((g) => g.value);
  subject.average = values.length ? round1(values.reduce((s, v) => s + v, 0) / values.length) : null;
  subject.absences = subject.grades.filter((g) => g.absent).length;
  return subject;
}

function mapAssignment(hw, closed) {
  const expires = parseSnDate(hw.expired_at);
  const result = hw.contingent?.result;
  return {
    id: String(hw.id),
    title: hw.name,
    subject: cleanSubjectName(hw.journal?.name),
    created_at: parseSnDate(hw.created_at),
    expires_at: expires,
    lesson_date: parseSnDay(hw.date_point),
    status: hw.contingent?.status || null,
    result: typeof result === 'number' ? result : null,
    url: hw.actions?.[0]?.link || null,
    closed,
    // "Current": still open and has to be handed in (or the deadline has not passed).
    is_current:
      !closed
      && (!DONE_STATUSES.includes(hw.contingent?.status) || (expires != null && new Date(expires) >= new Date())),
  };
}

export function buildStats(subjects) {
  const all = subjects.flatMap((s) => s.grades.filter((g) => g.value != null).map((g) => g.value));
  const averages = subjects.map((s) => s.average).filter((a) => a != null);
  return {
    gpa: averages.length ? round1(averages.reduce((s, v) => s + v, 0) / averages.length) : null,
    grades_count: all.length,
    excellent_count: all.filter((v) => v >= 90).length,
    retakes_count: all.filter((v) => v < 50).length,
    absences: subjects.reduce((s, x) => s + x.absences, 0),
    subjects_at_risk: subjects.filter((s) => s.average != null && s.average < 70).map((s) => s.name),
  };
}

/** Full snapshot. `client` is an already logged-in SmartNationClient. */
export async function buildSnapshot(client) {
  const [journals, summary] = await Promise.all([client.getJournals(), client.getSummary()]);
  const info = summary.data?.[0] || {};

  const subjects = await mapLimit(journals, 4, (j) => collectSubject(client, j));

  const disciplineIds = await client.getHomeworkDisciplineIds();
  const lists = await mapLimit(disciplineIds, 4, async (id) => {
    const [open, closed] = await Promise.all([client.getHomeworks(id), client.getHomeworks(id, { closed: true })]);
    return [...open.map((h) => mapAssignment(h, false)), ...closed.map((h) => mapAssignment(h, true))];
  });
  const assignments = lists.flat().sort((a, b) => String(b.expires_at).localeCompare(String(a.expires_at)));

  return {
    version: 1,
    synced_at: new Date().toISOString(),
    profile: {
      group: info.group || journals[0]?.group || null,
      course: info.course || null,
      qualification: info.qualification || null,
      curator: info.educator || null,
    },
    subjects,
    stats: buildStats(subjects),
    assignments,
  };
}

/** Light check at login: only the group and full name (no full journal walk). */
export async function fetchIdentity(client) {
  const [journals, summary] = await Promise.all([client.getJournals(), client.getSummary()]);
  const info = summary.data?.[0] || {};
  let fullName = null;
  if (journals[0]) {
    const c = await client.getContingent(journals[0].id);
    const me = (c.students || []).find((s) => s.isCurrent) || c.students?.[0];
    fullName = me?.fullName || null;
  }
  return { group: info.group || journals[0]?.group || null, course: info.course || null, fullName };
}

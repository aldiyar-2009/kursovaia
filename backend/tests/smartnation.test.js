import './setup.js';
import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { SmartNationClient } from '../src/services/smartnation/client.js';
import { buildSnapshot, cleanSubjectName, fetchIdentity, parseSnDate, parseSnDay } from '../src/services/smartnation/sync.js';
import { decrypt, encrypt } from '../src/utils/secret-box.js';
import { startFakeSmartNation } from './fake-smartnation.js';

describe('SmartNation client and snapshot (fake portal)', () => {
  let fake;
  before(async () => {
    fake = await startFakeSmartNation();
  });
  after(() => fake.close());

  const client = () => new SmartNationClient({ region: 'tko', baseUrl: fake.baseUrl });

  test('wrong password -> 401 SN_INVALID_CREDENTIALS', async () => {
    await assert.rejects(client().login('090204550001', 'wrong'), (e) => e.status === 401 && e.code === 'SN_INVALID_CREDENTIALS');
  });

  test('unreachable portal -> 502 SN_UNAVAILABLE', async () => {
    const c = new SmartNationClient({ baseUrl: 'http://127.0.0.1:1' });
    await assert.rejects(c.login('090204550001', 'x'), (e) => e.status === 502 && e.code === 'SN_UNAVAILABLE');
  });

  test('login by IIN and the group from the profile', async () => {
    const c = client();
    await c.login('090204550001', 'pw-090204550001');
    assert.deepEqual(await fetchIdentity(c), { group: 'ПО2406', course: 3, fullName: 'Студент 0001' });
  });

  test('snapshot: own grades only, stats, current and past assignments', async () => {
    const c = client();
    await c.login('090204550001', 'pw-090204550001');
    const s = await buildSnapshot(c);

    assert.equal(s.profile.group, 'ПО2406');
    const [subj] = s.subjects;
    assert.equal(subj.name, 'ПМ07-Разработка мобильных приложений');
    assert.deepEqual(subj.grades.map((g) => g.label), ['90', 'Н', '100']); // someone else's "10" is dropped
    assert.equal(subj.grades[0].date, '2026-10-13');
    assert.equal(subj.average, 95);
    assert.equal(subj.absences, 1);
    assert.equal(s.stats.gpa, 95);
    assert.equal(s.stats.excellent_count, 2);

    const current = s.assignments.filter((a) => a.is_current);
    const past = s.assignments.filter((a) => !a.is_current);
    assert.deepEqual(current.map((a) => a.title), ['Практическая 5']);
    assert.equal(current[0].lesson_date, '2026-10-29');
    assert.deepEqual(past.map((a) => [a.title, a.result]), [['Практическая 1', 95]]);
  });

  test('date helpers', () => {
    assert.equal(cleanSubjectName('3 курс ПМ07-Разработка мобильных приложений(ПО)'), 'ПМ07-Разработка мобильных приложений');
    assert.equal(parseSnDay('18.09.2026'), '2026-09-18');
    assert.equal(parseSnDay('garbage'), null);
    assert.equal(parseSnDate('25.09.2026 23:00'), '2026-09-25T18:00:00.000Z');
  });

  test('credentials are encrypted and decrypted', () => {
    const enc = encrypt({ login: 'x', password: 'secret-pass' });
    assert.ok(!enc.includes('secret-pass'));
    assert.deepEqual(decrypt(enc), { login: 'x', password: 'secret-pass' });
  });
});

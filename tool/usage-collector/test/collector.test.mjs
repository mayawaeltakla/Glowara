import test from 'node:test';
import assert from 'node:assert/strict';
import { addDays, computeStats, safeEqual, validatePing } from '../lib.js';
import { handle } from '../worker.js';

const NOW = new Date('2026-11-25T10:00:00Z');
const ID1 = 'a'.repeat(32);
const ID2 = 'b'.repeat(32);
const ID3 = 'c'.repeat(32);

const ping = (over = {}) => JSON.stringify({ id: ID1, v: '1.0.0', p: 'android', l: 'ar', d: '2026-11-25', ...over });

test('validatePing accepts a correct ping and returns only the five fields', () => {
  const r = validatePing(ping(), NOW);
  assert.equal(r.ok, true);
  assert.deepEqual(Object.keys(r.ping).sort(), ['d', 'id', 'l', 'p', 'v']);
});

test('validatePing rejects bad input', () => {
  const bad = [
    ['', 'body'],
    ['{not json', 'json'],
    ['[]', 'shape'],
    [ping({ extra: 'x' }), 'fields'],
    [JSON.stringify({ id: ID1, v: '1.0.0', p: 'android', l: 'ar' }), 'fields'],
    [ping({ id: 'short' }), 'id'],
    [ping({ id: 'G'.repeat(32) }), 'id'],
    [ping({ v: '1.0' }), 'version'],
    [ping({ v: '1.0.0; DROP TABLE pings' }), 'version'],
    [ping({ p: 'toaster' }), 'platform'],
    [ping({ l: 'fr' }), 'lang'],
    [ping({ d: 'yesterday' }), 'day'],
    [ping({ d: '2026-11-20' }), 'day-range'],
    [ping({ d: '2026-12-30' }), 'day-range'],
    ['x'.repeat(600), 'body'],
  ];
  for (const [raw, error] of bad) {
    const r = validatePing(raw, NOW);
    assert.equal(r.ok, false, String(raw).slice(0, 40));
    assert.equal(r.error, error, String(raw).slice(0, 40));
  }
});

test('validatePing allows one day either side for time zones', () => {
  assert.equal(validatePing(ping({ d: '2026-11-24' }), NOW).ok, true);
  assert.equal(validatePing(ping({ d: '2026-11-26' }), NOW).ok, true);
});

test('safeEqual', () => {
  assert.equal(safeEqual('abc', 'abc'), true);
  assert.equal(safeEqual('abc', 'abd'), false);
  assert.equal(safeEqual('abc', 'abcd'), false);
  assert.equal(safeEqual('', ''), true);
  assert.equal(safeEqual(undefined, 'a'), false);
});

test('computeStats: empty data is all zeros with a 30-day series', () => {
  const s = computeStats([], [], '2026-11-25');
  assert.equal(s.dau, 0);
  assert.equal(s.wau, 0);
  assert.equal(s.mau, 0);
  assert.equal(s.totalInstalls, 0);
  assert.equal(s.series.length, 30);
  assert.equal(s.series.at(-1).day, '2026-11-25');
  assert.equal(s.series[0].day, '2026-10-27');
});

test('computeStats: daily, weekly, monthly actives and installs', () => {
  const rows = [
    { day: '2026-11-25', id: ID1, v: '1.0.0', p: 'android', l: 'ar' },
    { day: '2026-11-24', id: ID1, v: '1.0.0', p: 'android', l: 'ar' },
    { day: '2026-11-22', id: ID2, v: '1.0.0', p: 'web', l: 'en' },
    { day: '2026-11-05', id: ID3, v: '0.9.0', p: 'android', l: 'ar' },
    { day: '2026-09-01', id: 'd'.repeat(32), v: '0.1.0', p: 'android', l: 'ar' }, // خارج 30 يومًا
  ];
  const firsts = [
    { id: ID1, first: '2026-11-24' },
    { id: ID2, first: '2026-11-22' },
    { id: ID3, first: '2026-11-05' },
    { id: 'd'.repeat(32), first: '2026-09-01' },
  ];
  const s = computeStats(rows, firsts, '2026-11-25');
  assert.equal(s.dau, 1);
  assert.equal(s.wau, 2); // ID1, ID2 (22 ضمن آخر 7 أيام: 19..25)
  assert.equal(s.mau, 3);
  assert.equal(s.totalInstalls, 4);
  assert.equal(s.newToday, 0);
  assert.deepEqual(s.byPlatform, { android: 2, web: 1 });
  assert.deepEqual(s.byLang, { ar: 2, en: 1 });
  assert.deepEqual(s.byVersion, { '1.0.0': 2, '0.9.0': 1 });
  const d24 = s.series.find((x) => x.day === '2026-11-24');
  assert.deepEqual(d24, { day: '2026-11-24', active: 1, new: 1 });
});

test('computeStats: one device is counted once per day even if it reports twice, and uses its latest report', () => {
  const rows = [
    { day: '2026-11-24', id: ID1, v: '1.0.0', p: 'android', l: 'ar' },
    { day: '2026-11-25', id: ID1, v: '1.1.0', p: 'android', l: 'en' },
  ];
  const s = computeStats(rows, [{ id: ID1, first: '2026-11-24' }], '2026-11-25');
  assert.equal(s.mau, 1);
  assert.deepEqual(s.byVersion, { '1.1.0': 1 });
  assert.deepEqual(s.byLang, { en: 1 });
});

// قاعدة D1 وهمية تحاكي الاستعلامات الثلاثة التي يستعملها الجامع.
function fakeDb() {
  const table = new Map(); // "day|id" -> row
  return {
    table,
    prepare(sql) {
      let args = [];
      const stmt = {
        bind: (...a) => ((args = a), stmt),
        async run() {
          assert.match(sql, /^INSERT OR REPLACE INTO pings/);
          const [day, id, v, p, l] = args;
          table.set(`${day}|${id}`, { day, id, v, p, l });
        },
        async all() {
          const rows = [...table.values()];
          if (sql.startsWith('SELECT day, id, v, p, l FROM pings WHERE day >= ?')) {
            return { results: rows.filter((r) => r.day >= args[0]) };
          }
          if (sql.startsWith('SELECT id, MIN(day) AS first FROM pings GROUP BY id')) {
            const m = new Map();
            for (const r of rows) if (!m.has(r.id) || r.day < m.get(r.id)) m.set(r.id, r.day);
            return { results: [...m].map(([id, first]) => ({ id, first })) };
          }
          throw new Error(`unexpected sql: ${sql}`);
        },
      };
      return stmt;
    },
  };
}

const req = (method, path, { body, token } = {}) =>
  new Request(`https://collector.test${path}`, {
    method,
    body,
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });

test('worker: stores a ping once per device per day and answers 204', async () => {
  const env = { DB: fakeDb(), ADMIN_TOKEN: 'secret-for-tests' };
  for (let i = 0; i < 3; i++) {
    const res = await handle(req('POST', '/ping', { body: ping() }), env, NOW);
    assert.equal(res.status, 204);
  }
  assert.equal(env.DB.table.size, 1);
});

test('worker: rejects invalid pings with 400 and stores nothing', async () => {
  const env = { DB: fakeDb(), ADMIN_TOKEN: 'secret-for-tests' };
  const res = await handle(req('POST', '/ping', { body: ping({ extra: 1 }) }), env, NOW);
  assert.equal(res.status, 400);
  assert.equal(env.DB.table.size, 0);
});

test('worker: /stats needs the admin token', async () => {
  const env = { DB: fakeDb(), ADMIN_TOKEN: 'secret-for-tests' };
  await handle(req('POST', '/', { body: ping() }), env, NOW);
  assert.equal((await handle(req('GET', '/stats'), env, NOW)).status, 401);
  assert.equal((await handle(req('GET', '/stats', { token: 'wrong' }), env, NOW)).status, 401);
  const ok = await handle(req('GET', '/stats', { token: 'secret-for-tests' }), env, NOW);
  assert.equal(ok.status, 200);
  const body = await ok.json();
  assert.equal(body.dau, 1);
  assert.equal(body.totalInstalls, 1);
  assert.equal(body.newToday, 1);
});

test('worker: with no ADMIN_TOKEN configured /stats is always refused', async () => {
  const env = { DB: fakeDb() };
  assert.equal((await handle(req('GET', '/stats', { token: '' }), env, NOW)).status, 401);
  assert.equal((await handle(req('GET', '/stats', { token: 'undefined' }), env, NOW)).status, 401);
});

test('worker: CORS preflight, unknown routes and methods', async () => {
  const env = { DB: fakeDb(), ADMIN_TOKEN: 't' };
  const pre = await handle(req('OPTIONS', '/ping'), env, NOW);
  assert.equal(pre.status, 204);
  assert.equal(pre.headers.get('Access-Control-Allow-Origin'), '*');
  assert.equal((await handle(req('GET', '/nothing'), env, NOW)).status, 404);
  assert.equal((await handle(req('DELETE', '/stats', { token: 't' }), env, NOW)).status, 404);
});

test('stats never contain the device ids', async () => {
  const env = { DB: fakeDb(), ADMIN_TOKEN: 't' };
  await handle(req('POST', '/', { body: ping() }), env, NOW);
  const text = await (await handle(req('GET', '/stats', { token: 't' }), env, NOW)).text();
  assert.equal(text.includes(ID1), false);
});

test('addDays crosses month and year boundaries', () => {
  assert.equal(addDays('2026-12-31', 1), '2027-01-01');
  assert.equal(addDays('2026-03-01', -1), '2026-02-28');
});

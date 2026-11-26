// جامع عدّ الاستخدام المجهول لغلوارا (Cloudflare Worker + D1).
//
// POST (أي مسار)  : يستقبل إشارة يومية مجهولة. يخزّن (يوم، معرّف عشوائي، نسخة، منصة، لغة).
// GET  /stats     : للمديرة فقط، برمز ADMIN_TOKEN (يُضبط كسرّ في Cloudflare، لا في الملفات).
//
// لا يخزّن عناوين IP ولا أي بيانات مستخدمة. الأرقام إرشادية وليست مضمونة ضد العبث.

import { computeStats, addDays, dayKey, safeEqual, validatePing } from './lib.js';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Max-Age': '86400',
};

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', ...CORS },
  });
}

export async function savePing(db, ping) {
  await db
    .prepare('INSERT OR REPLACE INTO pings (day, id, v, p, l) VALUES (?, ?, ?, ?, ?)')
    .bind(ping.d, ping.id, ping.v, ping.p, ping.l)
    .run();
}

export async function loadRows(db, sinceDay) {
  const { results } = await db
    .prepare('SELECT day, id, v, p, l FROM pings WHERE day >= ?')
    .bind(sinceDay)
    .all();
  return results ?? [];
}

export async function loadFirsts(db) {
  const { results } = await db.prepare('SELECT id, MIN(day) AS first FROM pings GROUP BY id').all();
  return results ?? [];
}

export async function handle(request, env, now = new Date()) {
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });

  const url = new URL(request.url);

  if (request.method === 'GET' && url.pathname === '/stats') {
    const header = request.headers.get('Authorization') ?? '';
    const given = header.startsWith('Bearer ') ? header.slice(7) : '';
    if (!env.ADMIN_TOKEN || !safeEqual(given, env.ADMIN_TOKEN)) return json({ error: 'unauthorized' }, 401);
    const today = dayKey(now);
    const [rows, firsts] = await Promise.all([loadRows(env.DB, addDays(today, -29)), loadFirsts(env.DB)]);
    return json(computeStats(rows, firsts, today));
  }

  if (request.method === 'POST') {
    const text = await request.text();
    const checked = validatePing(text, now);
    if (!checked.ok) return json({ error: checked.error }, 400);
    await savePing(env.DB, checked.ping);
    return new Response(null, { status: 204, headers: CORS });
  }

  return json({ error: 'not-found' }, 404);
}

export default {
  fetch: (request, env) => handle(request, env),
};

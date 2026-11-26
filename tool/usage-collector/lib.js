// منطق الجامع (دوال نقيّة قابلة للاختبار). لا يخزّن إلا ما يلزم لعدّ النشطات.

export const PLATFORMS = ['android', 'ios', 'web', 'windows', 'linux', 'macos', 'fuchsia'];
export const LANGS = ['ar', 'en'];
export const MAX_BODY_BYTES = 512;

const ID_RE = /^[0-9a-f]{32}$/;
const VERSION_RE = /^\d{1,3}\.\d{1,3}\.\d{1,3}$/;
const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;

/** تاريخ UTC بصيغة YYYY-MM-DD. */
export function dayKey(date) {
  return date.toISOString().slice(0, 10);
}

export function addDays(day, delta) {
  const d = new Date(`${day}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + delta);
  return dayKey(d);
}

/**
 * يتحقق من إشارة واحدة. يعيد { ok: true, ping } أو { ok: false, error }.
 * لا يقبل أي حقل غير الخمسة المعروفة، ولا تاريخًا بعيدًا عن اليوم (يوم قبل أو بعد فقط
 * لاختلاف المناطق الزمنية) كي لا يُملأ الماضي أو المستقبل.
 */
export function validatePing(raw, nowDate = new Date()) {
  if (typeof raw !== 'string' || raw.length === 0 || new TextEncoder().encode(raw).length > MAX_BODY_BYTES) {
    return { ok: false, error: 'body' };
  }
  let obj;
  try {
    obj = JSON.parse(raw);
  } catch {
    return { ok: false, error: 'json' };
  }
  if (obj === null || typeof obj !== 'object' || Array.isArray(obj)) return { ok: false, error: 'shape' };
  const keys = Object.keys(obj).sort().join(',');
  if (keys !== 'd,id,l,p,v') return { ok: false, error: 'fields' };
  const { id, v, p, l, d } = obj;
  if (typeof id !== 'string' || !ID_RE.test(id)) return { ok: false, error: 'id' };
  if (typeof v !== 'string' || !VERSION_RE.test(v)) return { ok: false, error: 'version' };
  if (typeof p !== 'string' || !PLATFORMS.includes(p)) return { ok: false, error: 'platform' };
  if (typeof l !== 'string' || !LANGS.includes(l)) return { ok: false, error: 'lang' };
  if (typeof d !== 'string' || !DAY_RE.test(d)) return { ok: false, error: 'day' };
  const today = dayKey(nowDate);
  if (d < addDays(today, -1) || d > addDays(today, 1)) return { ok: false, error: 'day-range' };
  return { ok: true, ping: { id, v, p, l, d } };
}

/** مقارنة بزمن ثابت لنصين (للرمز). */
export function safeEqual(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  let diff = x.length ^ y.length;
  const n = Math.max(x.length, y.length);
  for (let i = 0; i < n; i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

function countBy(rows, key) {
  const out = {};
  for (const r of rows) out[r[key]] = (out[r[key]] ?? 0) + 1;
  return out;
}

/**
 * يحسب الإحصاءات.
 * @param rows صفوف آخر 30 يومًا: { day, id, v, p, l } (صف واحد لكل معرّف في اليوم)
 * @param firsts لكل معرّف أول يوم ظهر فيه: { id, first }
 * @param today اليوم (UTC)
 */
export function computeStats(rows, firsts, today) {
  const since30 = addDays(today, -29);
  const since7 = addDays(today, -6);
  const inWindow = rows.filter((r) => r.day >= since30 && r.day <= today);

  const ids = (from) => new Set(inWindow.filter((r) => r.day >= from).map((r) => r.id));
  const dau = ids(today).size;
  const wau = ids(since7).size;
  const mau = ids(since30).size;

  const firstDay = new Map(firsts.map((f) => [f.id, f.first]));
  const totalInstalls = firsts.length;
  const newToday = firsts.filter((f) => f.first === today).length;

  const series = [];
  for (let i = 29; i >= 0; i--) {
    const day = addDays(today, -i);
    const active = new Set(inWindow.filter((r) => r.day === day).map((r) => r.id));
    let fresh = 0;
    for (const id of active) if (firstDay.get(id) === day) fresh++;
    series.push({ day, active: active.size, new: fresh });
  }

  // آخر ما أبلغ به كل معرّف نشط خلال 30 يومًا (للمنصة واللغة والنسخة).
  const latest = new Map();
  for (const r of inWindow) {
    const cur = latest.get(r.id);
    if (!cur || r.day >= cur.day) latest.set(r.id, r);
  }
  const latestRows = [...latest.values()];

  return {
    generatedFor: today,
    dau,
    wau,
    mau,
    totalInstalls,
    newToday,
    series,
    byPlatform: countBy(latestRows, 'p'),
    byLang: countBy(latestRows, 'l'),
    byVersion: countBy(latestRows, 'v'),
  };
}

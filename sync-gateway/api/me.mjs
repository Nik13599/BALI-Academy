import { json, safeError, verifySession, githubGet, decryptJson } from './_lib.mjs';

export default async function handler(req, res) {
  if (req.method !== 'GET') return json(res, 405, { error: 'method_not_allowed' });
  try {
    const session = verifySession(req);
    const file = await githubGet(`data/results/${session.sub}.json`);
    const attempts = file ? (decryptJson(file.text).attempts || []) : [];
    const avg = attempts.length ? Math.round(attempts.reduce((s,a)=>s+Number(a.percent||0),0)/attempts.length) : 0;
    const best = attempts.length ? Math.max(...attempts.map(a=>Number(a.percent||0))) : 0;
    const byCategory = {};
    for (const a of attempts) {
      const key = a.category || 'mixed';
      byCategory[key] ||= { sum: 0, count: 0 };
      byCategory[key].sum += Number(a.percent || 0);
      byCategory[key].count += 1;
    }
    const categories = Object.fromEntries(Object.entries(byCategory).map(([k,v])=>[k,Math.round(v.sum/v.count)]));
    return json(res, 200, {
      employee: { id: session.sub, fio: session.fio, role: session.role },
      attempts: attempts.slice(-50).reverse(),
      stats: { totalAttempts: attempts.length, avg, best, categories }
    });
  } catch (error) {
    const e = safeError(error);
    return json(res, e.status, e.body);
  }
}

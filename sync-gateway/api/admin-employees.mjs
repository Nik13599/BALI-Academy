import { json, safeError, requireAdmin, githubList, githubGet, decryptJson } from './_lib.mjs';

function summarize(attempts = []) {
  const totalAttempts = attempts.length;
  const avg = totalAttempts ? Math.round(attempts.reduce((s,a) => s + Number(a.percent || 0), 0) / totalAttempts) : 0;
  const best = totalAttempts ? Math.max(...attempts.map(a => Number(a.percent || 0))) : 0;
  const byCategory = {};
  for (const a of attempts) {
    const key = a.category || 'mixed';
    byCategory[key] ||= { attempts: 0, sum: 0 };
    byCategory[key].attempts += 1;
    byCategory[key].sum += Number(a.percent || 0);
  }
  const categories = Object.fromEntries(Object.entries(byCategory).map(([k,v]) => [k, Math.round(v.sum / v.attempts)]));
  const errors = attempts.flatMap(a => a.errors || []);
  const errorCounts = {};
  for (const e of errors) {
    const key = e.questionId || e.topic || 'unknown';
    errorCounts[key] = (errorCounts[key] || 0) + 1;
  }
  const weak = Object.entries(errorCounts).sort((a,b) => b[1]-a[1]).slice(0,10).map(([key,count]) => ({ key, count }));
  return { totalAttempts, avg, best, categories, weak, lastAttemptAt: attempts.at(-1)?.completedAt || null };
}

export default async function handler(req, res) {
  if (req.method !== 'GET') return json(res, 405, { error: 'method_not_allowed' });
  try {
    requireAdmin(req);
    const files = await githubList('data/employees');
    const employees = [];
    for (const file of files.filter(x => x.type === 'file' && x.name.endsWith('.json'))) {
      const employeeFile = await githubGet(file.path);
      if (!employeeFile) continue;
      const employee = decryptJson(employeeFile.text);
      const resultFile = await githubGet(`data/results/${employee.id}.json`);
      const attempts = resultFile ? (decryptJson(resultFile.text).attempts || []) : [];
      employees.push({
        id: employee.id,
        fio: employee.fio,
        role: employee.role,
        disabled: !!employee.disabled,
        createdAt: employee.createdAt,
        lastSeenAt: employee.lastSeenAt,
        deviceCount: (employee.devices || []).length,
        stats: summarize(attempts),
        attempts: attempts.slice().reverse()
      });
    }
    employees.sort((a,b) => String(a.fio).localeCompare(String(b.fio), 'ru'));
    return json(res, 200, { employees });
  } catch (error) {
    const e = safeError(error);
    return json(res, e.status, e.body);
  }
}

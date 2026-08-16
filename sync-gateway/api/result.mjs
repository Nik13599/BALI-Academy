import { readBody, json, safeError, verifySession, githubGet, githubPut, encryptJson, decryptJson } from './_lib.mjs';

export default async function handler(req, res) {
  if (req.method !== 'POST') return json(res, 405, { error: 'method_not_allowed' });
  try {
    const session = verifySession(req);
    const body = await readBody(req);
    const attempt = {
      id: String(body.id || cryptoRandomId()),
      mode: String(body.mode || 'quiz'),
      category: body.category || 'mixed',
      level: Number(body.level || 1),
      total: Number(body.total || 0),
      correct: Number(body.correct || 0),
      percent: Number(body.percent ?? (body.total ? Math.round((Number(body.correct || 0) / Number(body.total)) * 100) : 0)),
      errors: Array.isArray(body.errors) ? body.errors.slice(0, 500) : [],
      answers: Array.isArray(body.answers) ? body.answers.slice(0, 1000) : [],
      startedAt: body.startedAt || null,
      completedAt: body.completedAt || new Date().toISOString(),
      deviceId: session.deviceId
    };
    if (!attempt.total || attempt.correct < 0 || attempt.correct > attempt.total) {
      return json(res, 400, { error: 'invalid_result' });
    }

    const path = `data/results/${session.sub}.json`;
    const existing = await githubGet(path);
    const history = existing ? decryptJson(existing.text) : { employeeId: session.sub, attempts: [] };
    history.attempts = [...(history.attempts || []), attempt].slice(-500);
    history.updatedAt = new Date().toISOString();
    await githubPut(path, encryptJson(history), `Save training result ${session.sub}`, existing?.sha);
    return json(res, 200, { ok: true, attempt });
  } catch (error) {
    const e = safeError(error);
    return json(res, e.status, e.body);
  }
}

function cryptoRandomId() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

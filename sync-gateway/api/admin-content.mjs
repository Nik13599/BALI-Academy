import { readBody, json, safeError, requireAdmin, githubGet, githubPut } from './_lib.mjs';

export default async function handler(req, res) {
  try {
    requireAdmin(req);
    const file = await githubGet('content/bundle.json');
    if (req.method === 'GET') {
      if (!file) return json(res, 404, { error: 'content_not_found' });
      return json(res, 200, JSON.parse(file.text));
    }
    if (req.method === 'PUT') {
      const body = await readBody(req);
      if (!body || typeof body !== 'object' || !Array.isArray(body.products) || !Array.isArray(body.tests)) {
        return json(res, 400, { error: 'invalid_bundle' });
      }
      body.updatedAt = new Date().toISOString();
      await githubPut('content/bundle.json', JSON.stringify(body, null, 2) + '\n', 'Update BALI Academy content', file?.sha);
      return json(res, 200, { ok: true, updatedAt: body.updatedAt });
    }
    return json(res, 405, { error: 'method_not_allowed' });
  } catch (error) {
    const e = safeError(error);
    return json(res, e.status, e.body);
  }
}

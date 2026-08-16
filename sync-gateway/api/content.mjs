import { json, safeError, verifySession, loadBundle, publicProduct, entityCandidates } from './_lib.mjs';

export default async function handler(req, res) {
  if (req.method !== 'GET') return json(res, 405, { error: 'method_not_allowed' });
  try {
    const session = verifySession(req);
    const bundle = await loadBundle();
    const url = new URL(req.url, 'https://bali.local');
    const query = url.searchParams.get('q');

    if (query) {
      const matches = entityCandidates(query, bundle).map(x => ({
        type: x.type,
        id: x.id,
        name: x.name,
        score: x.score
      }));
      return json(res, 200, { matches });
    }

    const products = (bundle.products || []).map(p => publicProduct(p, session.role));
    const tests = (bundle.tests || []).filter(q => !q.roles || q.roles.includes(session.role));
    const cocktails = (bundle.cocktails || []).map(c => ({
      ...c,
      price: session.role === 'waiter' ? c.price || null : undefined
    }));
    return json(res, 200, {
      schemaVersion: bundle.schemaVersion,
      role: session.role,
      categories: bundle.categories || [],
      products,
      cocktails,
      tests,
      lessons: (bundle.lessons || []).filter(x => !x.roles || x.roles.includes(session.role))
    });
  } catch (error) {
    const e = safeError(error);
    return json(res, e.status, e.body);
  }
}

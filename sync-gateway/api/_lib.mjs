import crypto from 'node:crypto';

const OWNER_REPO = process.env.GITHUB_REPO || 'Nik13599/BALI-Academy';
const BRANCH = process.env.GITHUB_BRANCH || 'main';
const [OWNER, REPO] = OWNER_REPO.split('/');

export function json(res, status, body) {
  res.status(status).setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.end(JSON.stringify(body));
}

export function readBody(req) {
  if (req.body && typeof req.body === 'object') return Promise.resolve(req.body);
  return new Promise((resolve, reject) => {
    let raw = '';
    req.on('data', chunk => { raw += chunk; if (raw.length > 2_000_000) reject(new Error('Body too large')); });
    req.on('end', () => {
      try { resolve(raw ? JSON.parse(raw) : {}); } catch (e) { reject(e); }
    });
    req.on('error', reject);
  });
}

function requireEnv(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing environment variable: ${name}`);
  return value;
}

function githubHeaders() {
  return {
    Accept: 'application/vnd.github+json',
    Authorization: `Bearer ${requireEnv('GITHUB_TOKEN')}`,
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'BALI-Academy-Gateway'
  };
}

export async function githubGet(path) {
  const url = `https://api.github.com/repos/${OWNER}/${REPO}/contents/${path}?ref=${encodeURIComponent(BRANCH)}`;
  const r = await fetch(url, { headers: githubHeaders() });
  if (r.status === 404) return null;
  if (!r.ok) throw new Error(`GitHub GET ${path}: ${r.status} ${await r.text()}`);
  const data = await r.json();
  if (Array.isArray(data)) return data;
  const text = Buffer.from(data.content || '', 'base64').toString('utf8');
  return { ...data, text };
}

export async function githubList(path) {
  const data = await githubGet(path);
  return Array.isArray(data) ? data : [];
}

export async function githubPut(path, text, message, sha = undefined) {
  const url = `https://api.github.com/repos/${OWNER}/${REPO}/contents/${path}`;
  const payload = {
    message,
    branch: BRANCH,
    content: Buffer.from(text, 'utf8').toString('base64')
  };
  if (sha) payload.sha = sha;
  const r = await fetch(url, {
    method: 'PUT',
    headers: { ...githubHeaders(), 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  if (!r.ok) throw new Error(`GitHub PUT ${path}: ${r.status} ${await r.text()}`);
  return r.json();
}

export function normalizeText(value = '') {
  return String(value)
    .trim()
    .toLowerCase()
    .replace(/ё/g, 'е')
    .replace(/[’'`]/g, '')
    .replace(/[^a-zа-я0-9]+/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

export function normalizeFio(value = '') {
  return normalizeText(value)
    .split(' ')
    .filter(Boolean)
    .join(' ');
}

export function employeeId(fio, role) {
  const secret = requireEnv('ID_SECRET');
  return crypto.createHmac('sha256', secret)
    .update(`${normalizeFio(fio)}|${normalizeText(role)}`)
    .digest('hex')
    .slice(0, 32);
}

function encryptionKey() {
  return crypto.createHash('sha256').update(requireEnv('DATA_ENCRYPTION_KEY')).digest();
}

export function encryptJson(value) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', encryptionKey(), iv);
  const encrypted = Buffer.concat([cipher.update(JSON.stringify(value), 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return JSON.stringify({
    v: 1,
    alg: 'AES-256-GCM',
    iv: iv.toString('base64'),
    tag: tag.toString('base64'),
    data: encrypted.toString('base64')
  });
}

export function decryptJson(text) {
  const payload = JSON.parse(text);
  const decipher = crypto.createDecipheriv('aes-256-gcm', encryptionKey(), Buffer.from(payload.iv, 'base64'));
  decipher.setAuthTag(Buffer.from(payload.tag, 'base64'));
  const clear = Buffer.concat([
    decipher.update(Buffer.from(payload.data, 'base64')),
    decipher.final()
  ]).toString('utf8');
  return JSON.parse(clear);
}

function b64url(value) {
  return Buffer.from(value).toString('base64url');
}

export function signSession({ employeeId: id, role, fio, deviceId }) {
  const payload = {
    sub: id,
    role,
    fio,
    deviceId,
    iat: Date.now()
  };
  const encoded = b64url(JSON.stringify(payload));
  const signature = crypto.createHmac('sha256', requireEnv('SESSION_SECRET')).update(encoded).digest('base64url');
  return `${encoded}.${signature}`;
}

export function verifySession(req) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  const [encoded, signature] = token.split('.');
  if (!encoded || !signature) throw new Error('Unauthorized');
  const expected = crypto.createHmac('sha256', requireEnv('SESSION_SECRET')).update(encoded).digest('base64url');
  if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) throw new Error('Unauthorized');
  const payload = JSON.parse(Buffer.from(encoded, 'base64url').toString('utf8'));
  return payload;
}

export function requireAdmin(req) {
  const key = String(req.headers['x-admin-key'] || '');
  const expected = requireEnv('ADMIN_API_KEY');
  if (!key || key.length !== expected.length || !crypto.timingSafeEqual(Buffer.from(key), Buffer.from(expected))) {
    throw new Error('Unauthorized');
  }
}

export function translitVariants(value = '') {
  const s = normalizeText(value);
  const ruToLat = {а:'a',б:'b',в:'v',г:'g',д:'d',е:'e',ж:'zh',з:'z',и:'i',й:'y',к:'k',л:'l',м:'m',н:'n',о:'o',п:'p',р:'r',с:'s',т:'t',у:'u',ф:'f',х:'h',ц:'ts',ч:'ch',ш:'sh',щ:'sch',ы:'y',э:'e',ю:'yu',я:'ya',ь:'',ъ:''};
  const latToRuChunks = [
    ['sch','щ'],['sh','ш'],['ch','ч'],['zh','ж'],['yu','ю'],['ya','я'],['ts','ц']
  ];
  let latin = [...s].map(ch => ruToLat[ch] ?? ch).join('');
  let russian = s;
  for (const [a,b] of latToRuChunks) russian = russian.replaceAll(a,b);
  const simple = {a:'а',b:'б',v:'в',g:'г',d:'д',e:'е',z:'з',i:'и',y:'й',k:'к',l:'л',m:'м',n:'н',o:'о',p:'п',r:'р',s:'с',t:'т',u:'у',f:'ф',h:'х',c:'к',j:'дж',q:'к',w:'в',x:'кс'};
  russian = [...russian].map(ch => simple[ch] ?? ch).join('');
  return [...new Set([s, latin, russian].map(normalizeText).filter(Boolean))];
}

export function levenshtein(a, b) {
  a = normalizeText(a); b = normalizeText(b);
  const dp = Array.from({ length: a.length + 1 }, () => Array(b.length + 1).fill(0));
  for (let i = 0; i <= a.length; i++) dp[i][0] = i;
  for (let j = 0; j <= b.length; j++) dp[0][j] = j;
  for (let i = 1; i <= a.length; i++) {
    for (let j = 1; j <= b.length; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      dp[i][j] = Math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost);
    }
  }
  return dp[a.length][b.length];
}

export function entityCandidates(query, bundle, limit = 5) {
  const qVars = translitVariants(query);
  const entities = [
    ...(bundle.products || []).map(x => ({ type: 'product', id: x.id, name: x.name, aliases: x.aliases || [], data: x })),
    ...(bundle.cocktails || []).map(x => ({ type: 'cocktail', id: x.id, name: x.name, aliases: x.aliases || [], data: x }))
  ];
  const scored = [];
  for (const entity of entities) {
    const names = [entity.name, ...(entity.aliases || [])].flatMap(translitVariants);
    let best = 0;
    for (const q of qVars) {
      for (const n of names) {
        if (!q || !n) continue;
        if (q === n) best = Math.max(best, 1);
        else if (n.includes(q) || q.includes(n)) best = Math.max(best, 0.93);
        else {
          const dist = levenshtein(q, n);
          const score = 1 - dist / Math.max(q.length, n.length, 1);
          best = Math.max(best, score);
        }
      }
    }
    if (best >= 0.52) scored.push({ ...entity, score: Number(best.toFixed(3)) });
  }
  return scored.sort((a,b) => b.score - a.score).slice(0, limit);
}

export async function loadBundle() {
  const file = await githubGet('content/bundle.json');
  if (!file) throw new Error('Content bundle not found');
  return JSON.parse(file.text);
}

export function publicProduct(product, role) {
  const base = {
    id: product.id,
    name: product.name,
    category: product.category,
    country: product.country,
    aliases: product.aliases || [],
    image: product.image || null,
    short: product.short || '',
    service: product.service || null,
    taste: product.taste || [],
    available: product.available !== false
  };
  if (role === 'waiter') {
    base.price = product.price || null;
    base.sales = product.sales || null;
  }
  if (role === 'bartender') {
    base.bartender = product.bartender || null;
  }
  return base;
}

export function safeError(error) {
  console.error(error);
  if (String(error?.message || '').includes('Unauthorized')) return { status: 401, body: { error: 'unauthorized' } };
  return { status: 500, body: { error: 'server_error' } };
}

import OpenAI from 'openai';
import { readBody, json, safeError, verifySession, loadBundle, entityCandidates, publicProduct } from './_lib.mjs';

function pickContext(bundle, session, text) {
  const candidates = entityCandidates(text, bundle, 5);
  const strong = candidates.filter(x => x.score >= 0.72);
  if (strong.length >= 2 && Math.abs(strong[0].score - strong[1].score) < 0.11) {
    return { clarify: true, options: strong.slice(0, 3).map(x => ({ type: x.type, id: x.id, name: x.name })) };
  }
  if (strong.length === 1) {
    const x = strong[0];
    if (x.type === 'product') return { clarify: false, entities: [publicProduct(x.data, session.role)] };
    return { clarify: false, entities: [x.data] };
  }

  const words = String(text || '').toLowerCase().split(/\s+/).filter(x => x.length > 3);
  const lessons = (bundle.lessons || []).filter(l => words.some(w => JSON.stringify(l).toLowerCase().includes(w))).slice(0, 5);
  const tests = (bundle.tests || []).filter(q => words.some(w => JSON.stringify(q).toLowerCase().includes(w))).slice(0, 5);
  return { clarify: false, entities: [], lessons, tests };
}

export default async function handler(req, res) {
  if (req.method !== 'POST') return json(res, 405, { error: 'method_not_allowed' });
  try {
    const session = verifySession(req);
    const body = await readBody(req);
    const message = String(body.message || '').trim();
    const mode = String(body.mode || 'ask');
    if (!message) return json(res, 400, { error: 'message_required' });

    const bundle = await loadBundle();
    const context = pickContext(bundle, session, message);
    if (context.clarify) {
      return json(res, 200, {
        type: 'clarification',
        message: 'Нашёл несколько похожих вариантов. Выберите, что вы имели в виду:',
        options: context.options
      });
    }

    const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
    const roleRules = session.role === 'bartender'
      ? 'Бармену не показывай цены. Делай акцент на продукте, технологии, стекле, подаче, рецептуре, матчасти и профессиональной технике.'
      : 'Официанту показывай цену только если она присутствует в контексте. Делай акцент на меню, вкусе, рекомендации, сервисе, подаче и этичном апсейле.';

    const system = `Ты AI-тренер BALI Academy. Отвечай по-русски. Используй ТОЛЬКО утверждённый контекст BALI ниже. Не придумывай цены, наличие, рецептуры, историю бренда или технологию, которых нет в контексте. Если данных недостаточно — так и скажи и предложи открыть нужную карточку или обратиться к администратору. ${roleRules}\n\nРежим: ${mode}.\nЕсли режим sales — играй роль тренера по продажам: помогай выяснять предпочтения без давления, не используй манипуляции состоянием опьянения и не подталкивай явно нетрезвого гостя к дополнительному алкоголю.\nЕсли режим quiz — задай один вопрос, дождись ответа пользователя и только потом оценивай.\nЕсли режим explain — объясняй кратко и профессионально.\n\nКОНТЕКСТ BALI:\n${JSON.stringify(context).slice(0, 28000)}`;

    const response = await client.responses.create({
      model: process.env.OPENAI_MODEL || 'gpt-5.6',
      store: false,
      input: [
        { role: 'system', content: system },
        { role: 'user', content: message }
      ]
    });

    return json(res, 200, {
      type: 'answer',
      text: response.output_text || 'Не удалось сформировать ответ.',
      groundedEntities: (context.entities || []).map(x => ({ id: x.id, name: x.name }))
    });
  } catch (error) {
    const e = safeError(error);
    return json(res, e.status, e.body);
  }
}

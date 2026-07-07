import express from 'express';

const languages = new Set(['ru', 'kk', 'en']);
const lengthModes = {
  short: 20,
  medium: 40,
  detailed: 70,
};

const app = express();

app.use(express.json({ limit: '32kb' }));

app.get('/health', (_request, response) => {
  response.json({ ok: true });
});

app.post('/api/generate-facts', async (request, response) => {
  const validation = validateGenerateFactsRequest(request.body);
  if (!validation.ok) {
    return response.status(400).json({ error: validation.error });
  }

  const { topic, language, lengthMode, count } = validation.value;

  const aiProvider = getAiProviderConfig();
  if (!aiProvider) {
    return response.json({
      facts: makeMockFacts({ topic, language, lengthMode, count }),
      source: 'mock',
    });
  }

  try {
    const facts = await generateFactsWithAi({
      provider: aiProvider,
      topic,
      language,
      lengthMode,
      count,
      targetWords: lengthModes[lengthMode],
    });
    response.json({ facts, source: aiProvider.name });
  } catch (error) {
    response.status(502).json({
      error: 'AI provider failed to generate facts',
      details: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

export function validateGenerateFactsRequest(body) {
  if (!body || typeof body !== 'object') {
    return { ok: false, error: 'Request body must be a JSON object' };
  }

  const topic = typeof body.topic === 'string' ? body.topic.trim() : '';
  const language = typeof body.language === 'string' ? body.language : '';
  const lengthMode = typeof body.lengthMode === 'string' ? body.lengthMode : '';
  const count = Number(body.count ?? 1);

  if (topic.length < 2 || topic.length > 80) {
    return { ok: false, error: 'topic must be between 2 and 80 characters' };
  }
  if (!languages.has(language)) {
    return { ok: false, error: 'language must be one of ru, kk, en' };
  }
  if (!Object.hasOwn(lengthModes, lengthMode)) {
    return {
      ok: false,
      error: 'lengthMode must be one of short, medium, detailed',
    };
  }
  if (!Number.isInteger(count) || count < 1 || count > 8) {
    return { ok: false, error: 'count must be an integer from 1 to 8' };
  }

  return {
    ok: true,
    value: {
      topic,
      language,
      lengthMode,
      count,
    },
  };
}

export function makeMockFacts({ topic, language, lengthMode, count }) {
  return Array.from({ length: count }, (_, index) => {
    const number = index + 1;
    const suffix = lengthMode === 'detailed'
      ? ' Добавь один пример из жизни, чтобы лучше запомнить эту мысль.'
      : '';

    if (language === 'kk') {
      return {
        title: `${topic}: дерек ${number}`,
        body:
          `"${topic}" туралы шағын ой: бүгін бір сұрақ қойып, нақты жауап ізде. Қызығушылық күн сайын білімге айналады.`,
      };
    }

    if (language === 'en') {
      return {
        title: `${topic}: fact ${number}`,
        body:
          `A useful idea about "${topic}": ask one small question today and check the answer. Tiny curiosity builds durable knowledge.`,
      };
    }

    return {
      title: `${topic}: факт ${number}`,
      body:
        `Идея про "${topic}": выбери один маленький вопрос и найди ответ сегодня. Так интерес превращается в знание.${suffix}`,
    };
  });
}

function getAiProviderConfig() {
  const requestedProvider = (process.env.AI_PROVIDER || '').trim().toLowerCase();

  if (requestedProvider === 'cerebras') {
    return makeProviderConfig({
      name: 'cerebras',
      apiKey: process.env.CEREBRAS_API_KEY,
      baseUrl: process.env.CEREBRAS_BASE_URL || 'https://api.cerebras.ai/v1',
      model: process.env.CEREBRAS_MODEL || process.env.AI_MODEL || 'gemma-4-31b',
      supportsJsonMode: false,
    });
  }

  if (requestedProvider === 'openai') {
    return makeProviderConfig({
      name: 'openai',
      apiKey: process.env.OPENAI_API_KEY,
      baseUrl: process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1',
      model: process.env.OPENAI_MODEL || process.env.AI_MODEL || 'gpt-4.1-mini',
      supportsJsonMode: true,
    });
  }

  if (process.env.CEREBRAS_API_KEY) {
    return makeProviderConfig({
      name: 'cerebras',
      apiKey: process.env.CEREBRAS_API_KEY,
      baseUrl: process.env.CEREBRAS_BASE_URL || 'https://api.cerebras.ai/v1',
      model: process.env.CEREBRAS_MODEL || process.env.AI_MODEL || 'gemma-4-31b',
      supportsJsonMode: false,
    });
  }

  if (process.env.OPENAI_API_KEY) {
    return makeProviderConfig({
      name: 'openai',
      apiKey: process.env.OPENAI_API_KEY,
      baseUrl: process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1',
      model: process.env.OPENAI_MODEL || process.env.AI_MODEL || 'gpt-4.1-mini',
      supportsJsonMode: true,
    });
  }

  return null;
}

function makeProviderConfig({ name, apiKey, baseUrl, model, supportsJsonMode }) {
  const trimmedApiKey = typeof apiKey === 'string' ? apiKey.trim() : '';
  if (!trimmedApiKey) {
    return null;
  }

  return {
    name,
    apiKey: trimmedApiKey,
    baseUrl: baseUrl.replace(/\/+$/, ''),
    model,
    supportsJsonMode,
  };
}

async function generateFactsWithAi({
  provider,
  topic,
  language,
  lengthMode,
  count,
  targetWords,
}) {
  const requestBody = {
    model: provider.model,
    temperature: 0.7,
    messages: [
      {
        role: 'system',
        content:
          'You create concise educational notification text. Respond only with valid JSON: {"facts":[{"title":"...","body":"..."}]}. Do not wrap it in markdown.',
      },
      {
        role: 'user',
        content: [
          `Topic: ${topic}`,
          `Language: ${language}`,
          `Length mode: ${lengthMode}`,
          `Target body length: about ${targetWords} words`,
          `Count: ${count}`,
          'Each fact must be useful, specific, safe, and readable as a phone notification.',
        ].join('\n'),
      },
    ],
  };

  if (provider.supportsJsonMode) {
    requestBody.response_format = { type: 'json_object' };
  }

  const response = await fetch(`${provider.baseUrl}/chat/completions`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${provider.apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(requestBody),
  });

  if (!response.ok) {
    const details = await response.text();
    throw new Error(`${provider.name} HTTP ${response.status}: ${details.slice(0, 300)}`);
  }

  const decoded = await response.json();
  const content = decoded?.choices?.[0]?.message?.content;
  if (typeof content !== 'string') {
    throw new Error(`${provider.name} response did not include message content`);
  }

  const parsed = parseJsonObject(content);
  if (!Array.isArray(parsed.facts)) {
    throw new Error(`${provider.name} response JSON did not include facts array`);
  }

  return parsed.facts
    .map((fact) => ({
      title: String(fact.title ?? '').trim(),
      body: String(fact.body ?? '').trim(),
    }))
    .filter((fact) => fact.title && fact.body)
    .slice(0, count);
}

function parseJsonObject(content) {
  try {
    return JSON.parse(content);
  } catch {
    const start = content.indexOf('{');
    const end = content.lastIndexOf('}');
    if (start === -1 || end === -1 || end <= start) {
      throw new Error('AI response was not valid JSON');
    }

    return JSON.parse(content.slice(start, end + 1));
  }
}

export default app;

import express from 'express';

const languages = new Set(['ru', 'kk', 'en']);
const lengthModes = {
  short: 20,
  medium: 40,
  detailed: 70,
};
const maxExcludedFacts = 30;
const maxExcludedTitleLength = 160;
const maxExcludedBodyLength = 700;
const languageNames = {
  ru: 'Russian',
  kk: 'Kazakh',
  en: 'English',
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

  const { topic, language, lengthMode, count, excludedFacts } = validation.value;

  const aiProvider = getAiProviderConfig();
  if (aiProvider?.error) {
    return response.status(503).json({ error: aiProvider.error });
  }

  if (!aiProvider) {
    return response.json({
      facts: makeMockFacts({
        topic,
        language,
        lengthMode,
        count,
        excludedFacts,
      }),
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
      excludedFacts,
    });
    if (facts.length === 0) {
      throw new Error('AI provider returned no usable facts');
    }
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
  const excludedFactsValidation = validateExcludedFacts(body.excludedFacts);

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
  if (!excludedFactsValidation.ok) {
    return { ok: false, error: excludedFactsValidation.error };
  }

  return {
    ok: true,
    value: {
      topic,
      language,
      lengthMode,
      count,
      excludedFacts: excludedFactsValidation.value,
    },
  };
}

function validateExcludedFacts(rawExcludedFacts) {
  if (rawExcludedFacts === undefined) {
    return { ok: true, value: [] };
  }

  if (!Array.isArray(rawExcludedFacts)) {
    return { ok: false, error: 'excludedFacts must be an array' };
  }
  if (rawExcludedFacts.length > maxExcludedFacts) {
    return {
      ok: false,
      error: `excludedFacts must include at most ${maxExcludedFacts} items`,
    };
  }

  const excludedFacts = [];
  for (const [index, fact] of rawExcludedFacts.entries()) {
    if (!fact || typeof fact !== 'object' || Array.isArray(fact)) {
      return {
        ok: false,
        error: `excludedFacts[${index}] must be an object`,
      };
    }

    const title = typeof fact.title === 'string' ? fact.title.trim() : '';
    const body = typeof fact.body === 'string' ? fact.body.trim() : '';
    if (title.length > maxExcludedTitleLength) {
      return {
        ok: false,
        error: `excludedFacts[${index}].title is too long`,
      };
    }
    if (body.length > maxExcludedBodyLength) {
      return {
        ok: false,
        error: `excludedFacts[${index}].body is too long`,
      };
    }

    if (title || body) {
      excludedFacts.push({ title, body });
    }
  }

  return { ok: true, value: excludedFacts };
}

export function makeMockFacts({
  topic,
  language,
  lengthMode,
  count,
  excludedFacts = [],
}) {
  const baseNumber = Date.now() % 9000;
  const usedFingerprints = new Set(
    excludedFacts.map((fact) => factFingerprint(fact.title, fact.body)),
  );

  const candidates = Array.from(
    { length: count + maxExcludedFacts + 20 },
    (_, index) => {
    const number = baseNumber + index + 1;
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

  return candidates
    .filter((fact) => {
      const fingerprint = factFingerprint(fact.title, fact.body);
      if (!fingerprint || usedFingerprints.has(fingerprint)) {
        return false;
      }
      usedFingerprints.add(fingerprint);
      return true;
    })
    .slice(0, count);
}

function getAiProviderConfig() {
  const requestedProvider = (process.env.AI_PROVIDER || '').trim().toLowerCase();

  if (requestedProvider &&
      requestedProvider !== 'cerebras' &&
      requestedProvider !== 'openai') {
    return {
      error: 'AI_PROVIDER must be empty, "cerebras", or "openai"',
    };
  }

  if (requestedProvider === 'cerebras') {
    return makeProviderConfig({
      name: 'cerebras',
      apiKeyName: 'CEREBRAS_API_KEY',
      apiKey: process.env.CEREBRAS_API_KEY,
      baseUrl: process.env.CEREBRAS_BASE_URL || 'https://api.cerebras.ai/v1',
      model: process.env.CEREBRAS_MODEL || process.env.AI_MODEL || 'gemma-4-31b',
      supportsJsonMode: false,
    });
  }

  if (requestedProvider === 'openai') {
    return makeProviderConfig({
      name: 'openai',
      apiKeyName: 'OPENAI_API_KEY',
      apiKey: process.env.OPENAI_API_KEY,
      baseUrl: process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1',
      model: process.env.OPENAI_MODEL || process.env.AI_MODEL || 'gpt-4.1-mini',
      supportsJsonMode: true,
    });
  }

  if (process.env.CEREBRAS_API_KEY) {
    return makeProviderConfig({
      name: 'cerebras',
      apiKeyName: 'CEREBRAS_API_KEY',
      apiKey: process.env.CEREBRAS_API_KEY,
      baseUrl: process.env.CEREBRAS_BASE_URL || 'https://api.cerebras.ai/v1',
      model: process.env.CEREBRAS_MODEL || process.env.AI_MODEL || 'gemma-4-31b',
      supportsJsonMode: false,
    });
  }

  if (process.env.OPENAI_API_KEY) {
    return makeProviderConfig({
      name: 'openai',
      apiKeyName: 'OPENAI_API_KEY',
      apiKey: process.env.OPENAI_API_KEY,
      baseUrl: process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1',
      model: process.env.OPENAI_MODEL || process.env.AI_MODEL || 'gpt-4.1-mini',
      supportsJsonMode: true,
    });
  }

  return null;
}

function makeProviderConfig({
  name,
  apiKeyName,
  apiKey,
  baseUrl,
  model,
  supportsJsonMode,
}) {
  const trimmedApiKey = typeof apiKey === 'string' ? apiKey.trim() : '';
  if (!trimmedApiKey) {
    return {
      error: `${apiKeyName} is required for ${name} generation`,
    };
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
  excludedFacts,
}) {
  const languageName = languageNames[language];
  const candidateCount = Math.min(8, count + (excludedFacts.length > 0 ? 3 : 0));
  const requestBody = {
    model: provider.model,
    temperature: 0.9,
    messages: [
      {
        role: 'system',
        content:
          'You create concise educational facts for phone notifications. Respond only with valid JSON: {"facts":[{"title":"...","body":"..."}]}. Do not wrap it in markdown. Do not give generic study advice; each item must contain a concrete fact about the topic. Every returned fact must be new and must not repeat the provided previous facts.',
      },
      {
        role: 'user',
        content: [
          `Topic: ${topic}`,
          `Language: ${languageName} (${language})`,
          `Length mode: ${lengthMode}`,
          `Target body length: about ${targetWords} words`,
          `Count: ${candidateCount}`,
          'Write every title and body in the requested language only.',
          'Each fact must be useful, specific, safe, and readable as a phone notification.',
          'Avoid templates like "ask one question", "learn more", or "check the answer"; include the actual fact.',
          'Avoid repeating the same fact, idea, example, mechanism, statistic, or wording from the previous facts.',
          excludedFacts.length > 0
            ? `Previous facts to avoid:\n${formatExcludedFactsForPrompt(excludedFacts)}`
            : 'No previous facts were provided.',
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

  const facts = [];
  for (const rawFact of parsed.facts) {
    const fact = {
      title: String(rawFact?.title ?? '').trim(),
      body: String(rawFact?.body ?? '').trim(),
    };
    if (!fact.title || !fact.body) {
      continue;
    }
    if (isDuplicateFact(fact, [...excludedFacts, ...facts])) {
      continue;
    }
    facts.push(fact);
    if (facts.length === count) {
      break;
    }
  }

  if (facts.length === 0) {
    throw new Error(`${provider.name} response did not include usable facts`);
  }

  return facts;
}

function formatExcludedFactsForPrompt(excludedFacts) {
  return excludedFacts
    .slice(0, maxExcludedFacts)
    .map((fact, index) => (
      `${index + 1}. Title: ${fact.title}\n   Body: ${fact.body}`
    ))
    .join('\n');
}

function isDuplicateFact(candidate, existingFacts) {
  const candidateFingerprint = factFingerprint(candidate.title, candidate.body);
  if (!candidateFingerprint) {
    return true;
  }

  const candidateTokens = tokenSet(candidate);
  for (const existingFact of existingFacts) {
    if (candidateFingerprint === factFingerprint(
      existingFact.title,
      existingFact.body,
    )) {
      return true;
    }

    const existingTokens = tokenSet(existingFact);
    const minSize = Math.min(candidateTokens.size, existingTokens.size);
    if (minSize < 6) {
      continue;
    }

    let shared = 0;
    for (const token of candidateTokens) {
      if (existingTokens.has(token)) {
        shared += 1;
      }
    }
    if (shared / minSize >= 0.82) {
      return true;
    }
  }

  return false;
}

function tokenSet(fact) {
  return new Set(
    factFingerprint(fact.title, fact.body)
      .split(/[^\p{L}\p{N}]+/u)
      .filter((token) => token.length > 2),
  );
}

function factFingerprint(title, body) {
  return normalizeText(`${title} ${body}`);
}

function normalizeText(value) {
  return String(value ?? '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
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

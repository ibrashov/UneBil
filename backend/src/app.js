import express from 'express';

import {
  factFingerprint,
  isDuplicateFact,
} from './fact-deduplicator.js';

const languages = new Set(['ru', 'kk', 'en']);
const lengthModes = {
  short: 20,
  medium: 40,
  detailed: 70,
};
const maxExcludedFacts = 120;
const maxExcludedTitleLength = 160;
const maxExcludedBodyLength = 700;
const maxExcludedKeyLength = 180;
export const FACT_GENERATION_BATCH_SIZE = 10;
const maxFactGenerationBatchSize = 20;
const providerRequestTimeoutMs = 60000;
const languageNames = {
  ru: 'Russian',
  kk: 'Kazakh',
  en: 'English',
};

const app = express();

app.use(express.json({ limit: '128kb' }));

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
    if (!mockFactsEnabled()) {
      return response.status(503).json({
        error: 'AI provider is not configured',
      });
    }
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
    const generation = await generateFactsWithAi({
      provider: aiProvider,
      topic,
      language,
      lengthMode,
      count,
      targetWords: lengthModes[lengthMode],
      excludedFacts,
    });
    if (generation.facts.length === 0) {
      throw new Error('AI provider returned no usable facts');
    }
    response.json({
      facts: generation.facts,
      source: aiProvider.name,
      generation: generation.metrics,
    });
  } catch (error) {
    const failure = describeAiProviderFailure(error);
    if (failure.retryAfter) {
      response.set('Retry-After', failure.retryAfter);
    }
    console.error(
      '[FactGeneration] Provider request failed:',
      error instanceof Error ? error.message : error,
    );
    response.status(failure.statusCode).json({
      error: failure.message,
      code: failure.code,
    });
  }
});

export function describeAiProviderFailure(error) {
  if (error instanceof AiProviderHttpError) {
    if (error.statusCode === 402) {
      return {
        statusCode: 402,
        code: 'provider_payment_required',
        message: 'AI provider billing or quota is unavailable',
        retryAfter: null,
      };
    }
    if (error.statusCode === 429) {
      return {
        statusCode: 429,
        code: 'provider_rate_limited',
        message: 'AI provider rate limit reached',
        retryAfter: error.retryAfter,
      };
    }
    if (error.statusCode === 401 || error.statusCode === 403) {
      return {
        statusCode: 502,
        code: 'provider_authentication_failed',
        message: 'AI provider rejected its credentials',
        retryAfter: null,
      };
    }
  }

  return {
    statusCode: 502,
    code: 'provider_generation_failed',
    message: 'AI provider failed to generate facts',
    retryAfter: null,
  };
}

export function validateGenerateFactsRequest(body) {
  if (!body || typeof body !== 'object') {
    return { ok: false, error: 'Request body must be a JSON object' };
  }

  const topic = typeof body.topic === 'string' ? body.topic.trim() : '';
  const language = typeof body.language === 'string' ? body.language : '';
  const lengthMode = typeof body.lengthMode === 'string' ? body.lengthMode : '';
  const count = Number(body.count ?? FACT_GENERATION_BATCH_SIZE);
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
  if (!Number.isInteger(count) ||
      count < 1 ||
      count > maxFactGenerationBatchSize) {
    return {
      ok: false,
      error: `count must be an integer from 1 to ${maxFactGenerationBatchSize}`,
    };
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
    const key = typeof fact.key === 'string' ? fact.key.trim() : '';
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
    if (key.length > maxExcludedKeyLength) {
      return {
        ok: false,
        error: `excludedFacts[${index}].key is too long`,
      };
    }

    if (title || body) {
      excludedFacts.push({ title, body, key });
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
          `[Mock ${number}] "${topic}" тақырыбына арналған сынақ жауабы. Нақты дерек алу үшін AI провайдерін баптаңыз.`,
        key: `mock|${topic}|${number}`,
      };
    }

    if (language === 'en') {
      return {
        title: `${topic}: fact ${number}`,
        body:
          `[Mock ${number}] Test response for "${topic}". Configure an AI provider to receive a real educational fact.`,
        key: `mock|${topic}|${number}`,
      };
    }

    return {
      title: `${topic}: факт ${number}`,
      body:
        `[Mock ${number}] Тестовый ответ по теме "${topic}". Настрой AI-провайдер, чтобы получить настоящий образовательный факт.${suffix}`,
      key: `mock|${topic}|${number}`,
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

function mockFactsEnabled() {
  return ['1', 'true'].includes(
    String(process.env.ALLOW_MOCK_FACTS ?? '').trim().toLowerCase(),
  );
}

function getAiProviderConfig() {
  const requestedProvider = (process.env.AI_PROVIDER || '').trim().toLowerCase();

  if (requestedProvider &&
      requestedProvider !== 'cerebras' &&
      requestedProvider !== 'openai' &&
      requestedProvider !== 'inception') {
    return {
      error: 'AI_PROVIDER must be empty, "cerebras", "openai", or "inception"',
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

  if (requestedProvider === 'inception') {
    return makeProviderConfig({
      name: 'inception',
      apiKeyName: 'INCEPTION_API_KEY',
      apiKey: process.env.INCEPTION_API_KEY,
      baseUrl: process.env.INCEPTION_BASE_URL || 'https://api.inceptionlabs.ai/v1',
      model: process.env.INCEPTION_MODEL || 'mercury-2',
      supportsJsonMode: false,
      reasoningEffort: process.env.INCEPTION_REASONING_EFFORT || 'low',
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
      maxCompletionTokens: Number(process.env.OPENAI_MAX_COMPLETION_TOKENS),
    });
  }

  if (process.env.INCEPTION_API_KEY) {
    return makeProviderConfig({
      name: 'inception',
      apiKeyName: 'INCEPTION_API_KEY',
      apiKey: process.env.INCEPTION_API_KEY,
      baseUrl: process.env.INCEPTION_BASE_URL || 'https://api.inceptionlabs.ai/v1',
      model: process.env.INCEPTION_MODEL || 'mercury-2',
      supportsJsonMode: false,
      reasoningEffort: process.env.INCEPTION_REASONING_EFFORT || 'low',
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
      maxCompletionTokens: Number(process.env.OPENAI_MAX_COMPLETION_TOKENS),
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
  maxCompletionTokens,
  reasoningEffort,
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
    ...(Number.isInteger(maxCompletionTokens) && maxCompletionTokens > 0
      ? { maxCompletionTokens }
      : {}),
    ...(reasoningEffort ? { reasoningEffort } : {}),
  };
}

export async function generateFactsWithAi({
  provider,
  topic,
  language,
  lengthMode,
  count,
  targetWords,
  excludedFacts,
  fetchImpl = fetch,
  logger = console,
}) {
  const languageName = languageNames[language];
  const startedAt = performance.now();
  const acceptedFacts = [];
  let duplicatesRemoved = 0;
  const batch = await requestAiBatch({
    provider,
    topic,
    language,
    languageName,
    lengthMode,
    targetWords,
    count,
    factsToAvoid: prioritizedAvoidedFacts(excludedFacts),
    fetchImpl,
    logger,
  });

  duplicatesRemoved += batch.duplicatesRemoved;
  for (const fact of batch.facts) {
    if (isDuplicateFact(fact, [...excludedFacts, ...acceptedFacts])) {
      duplicatesRemoved += 1;
      continue;
    }
    acceptedFacts.push(fact);
  }

  if (acceptedFacts.length === 0) {
    throw new Error(`${provider.name} response did not include any usable new facts`);
  }

  const facts = acceptedFacts.slice(0, count);
  const durationMs = Math.round(performance.now() - startedAt);
  const metrics = {
    requestedFacts: count,
    receivedFacts: batch.receivedFacts,
    validFacts: facts.length,
    invalidFactsRemoved: batch.invalidFactsRemoved,
    duplicatesRemoved,
    providerRequests: 1,
    durationMs,
    ...(batch.usage ? { usage: batch.usage } : {}),
  };

  if (facts.length < count) {
    logger.warn(
      `[FactGeneration] Expected ${count} facts but accepted ${facts.length}.`,
    );
  }
  logGenerationSummary(logger, {
    topic,
    providerName: provider.name,
    metrics,
  });

  return { facts, metrics };
}

async function requestAiBatch({
  provider,
  topic,
  language,
  languageName,
  lengthMode,
  targetWords,
  count,
  factsToAvoid,
  fetchImpl,
  logger,
}) {
  const requestBody = {
    model: provider.model,
    temperature: 0.9,
    messages: [
      {
        role: 'system',
        content:
          'You create educational facts for phone notifications. Return only one valid JSON object with exactly this shape: {"facts":[{"key":"canonical subject|single claim in 2-6 English words","title":"...","content":"..."}]}. Do not use Markdown fences and do not add text before or after the JSON. The key identifies the underlying claim, not its wording, so paraphrases of one claim must use the same key. Every item must contain a concrete fact about the requested topic.',
      },
      {
        role: 'user',
        content: [
          `Topic: ${topic}`,
          `Language: ${languageName} (${language})`,
          `Length mode: ${lengthMode}`,
          `Target content length: about ${targetWords} words`,
          `Generate exactly ${count} facts in the single facts array.`,
          'Write every title and content value in the requested language only.',
          'Each fact must be useful, specific, safe, and readable as a phone notification.',
          'Avoid templates like "ask one question", "learn more", or "check the answer"; include the actual fact.',
          'Prefer a less obvious entity or subtopic instead of the most famous fact about a broad topic.',
          'Make all facts distinct. Do not repeat one idea, claim, example, mechanism, statistic, or entity-property pair with different wording.',
          'Avoid repeating the same claim, idea, example, mechanism, statistic, entity-property pair, or wording from the previous facts.',
          factsToAvoid.length > 0
            ? `Previous and rejected facts to avoid:\n${formatExcludedFactsForPrompt(factsToAvoid)}`
            : 'No previous facts were provided.',
        ].join('\n'),
      },
    ],
  };

  if (provider.supportsJsonMode) {
    requestBody.response_format = { type: 'json_object' };
  }
  if (provider.maxCompletionTokens) {
    requestBody.max_completion_tokens = provider.maxCompletionTokens;
  }
  if (provider.reasoningEffort) {
    requestBody.reasoning_effort = provider.reasoningEffort;
  }

  const response = await fetchImpl(`${provider.baseUrl}/chat/completions`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${provider.apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(requestBody),
    signal: AbortSignal.timeout(providerRequestTimeoutMs),
  });

  if (!response.ok) {
    const details = await response.text();
    throw new AiProviderHttpError(
      provider.name,
      response.status,
      details.slice(0, 300),
      response.headers.get('retry-after'),
    );
  }

  const decoded = await response.json();
  const content = decoded?.choices?.[0]?.message?.content;
  if (typeof content !== 'string') {
    throw new Error(`${provider.name} response did not include message content`);
  }

  let parsed;
  try {
    parsed = parseAiJsonObject(content);
  } catch (error) {
    if (process.env.NODE_ENV !== 'production') {
      logger.error('[FactGeneration] Raw invalid AI response:', content);
    }
    throw error;
  }
  if (!Array.isArray(parsed.facts)) {
    throw new Error(`${provider.name} response JSON did not include facts array`);
  }

  const facts = [];
  let invalidFactsRemoved = 0;
  let duplicatesRemoved = 0;
  for (const rawFact of parsed.facts) {
    if (!rawFact || typeof rawFact !== 'object' || Array.isArray(rawFact) ||
        typeof rawFact.title !== 'string' ||
        typeof rawFact.content !== 'string' ||
        (rawFact.key !== undefined && typeof rawFact.key !== 'string')) {
      invalidFactsRemoved += 1;
      continue;
    }
    const title = rawFact.title.trim();
    const body = rawFact.content.trim();
    const rawKey = (rawFact.key ?? '').trim();
    const fact = {
      key: rawKey.slice(0, maxExcludedKeyLength),
      title,
      body,
    };
    if (!fact.title || !fact.body ||
        fact.title.length > maxExcludedTitleLength ||
        fact.body.length > maxExcludedBodyLength) {
      invalidFactsRemoved += 1;
      continue;
    }
    if (isDuplicateFact(fact, facts)) {
      duplicatesRemoved += 1;
      continue;
    }
    facts.push(fact);
    if (facts.length === count) {
      break;
    }
  }

  return {
    facts,
    receivedFacts: parsed.facts.length,
    invalidFactsRemoved,
    duplicatesRemoved,
    usage: normalizeUsage(decoded.usage),
  };
}

function prioritizedAvoidedFacts(excludedFacts) {
  const result = [];
  for (const fact of excludedFacts) {
    if (!isDuplicateFact(fact, result)) {
      result.push(fact);
    }
    if (result.length === maxExcludedFacts) {
      break;
    }
  }
  return result;
}

function formatExcludedFactsForPrompt(excludedFacts) {
  return excludedFacts
    .slice(0, maxExcludedFacts)
    .map((fact, index) => [
      `${index + 1}. Key: ${fact.key || '(unknown)'}`,
      `   Title: ${fact.title}`,
      `   Body: ${fact.body.slice(0, 320)}`,
    ].join('\n'))
    .join('\n');
}

export function parseAiJsonObject(content) {
  if (typeof content !== 'string') {
    throw new Error('AI response was not valid JSON');
  }

  let jsonText = content.trim();
  const fencedMatch = jsonText.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/iu);
  if (fencedMatch) {
    jsonText = fencedMatch[1].trim();
  }

  const candidateTexts = [jsonText];
  if (jsonText.endsWith('}.')) {
    candidateTexts.push(jsonText.slice(0, -1));
  }

  let parseError;
  for (const candidateText of candidateTexts) {
    try {
      const parsed = JSON.parse(candidateText);
      if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
        throw new Error('AI response JSON must be an object');
      }
      return parsed;
    } catch (error) {
      if (error instanceof Error &&
          error.message === 'AI response JSON must be an object') {
        throw error;
      }
      parseError = error;
    }
  }

  throw new Error('AI response was not valid JSON', { cause: parseError });
}

function normalizeUsage(rawUsage) {
  if (!rawUsage || typeof rawUsage !== 'object') {
    return null;
  }
  const usage = {};
  for (const [sourceKey, targetKey] of [
    ['prompt_tokens', 'inputTokens'],
    ['completion_tokens', 'outputTokens'],
    ['total_tokens', 'totalTokens'],
  ]) {
    if (Number.isFinite(rawUsage[sourceKey])) {
      usage[targetKey] = rawUsage[sourceKey];
    }
  }
  return Object.keys(usage).length > 0 ? usage : null;
}

function logGenerationSummary(logger, { topic, providerName, metrics }) {
  const usageLines = metrics.usage
    ? [
        metrics.usage.inputTokens === undefined
          ? null
          : `Input tokens: ${metrics.usage.inputTokens}`,
        metrics.usage.outputTokens === undefined
          ? null
          : `Output tokens: ${metrics.usage.outputTokens}`,
        metrics.usage.totalTokens === undefined
          ? null
          : `Total tokens: ${metrics.usage.totalTokens}`,
      ].filter(Boolean)
    : [];
  logger.info([
    '[FactGeneration]',
    `Topic: ${topic}`,
    `Requested facts: ${metrics.requestedFacts}`,
    `AI provider: ${providerName}`,
    `AI provider requests: ${metrics.providerRequests}`,
    `Generation duration: ${(metrics.durationMs / 1000).toFixed(2)}s`,
    `Facts received: ${metrics.receivedFacts}`,
    `Valid facts: ${metrics.validFacts}`,
    `Invalid facts removed: ${metrics.invalidFactsRemoved}`,
    `Duplicates removed: ${metrics.duplicatesRemoved}`,
    ...usageLines,
  ].join('\n'));
}

export class AiProviderHttpError extends Error {
  constructor(providerName, statusCode, details, retryAfter = null) {
    super(`${providerName} HTTP ${statusCode}: ${details}`);
    this.name = 'AiProviderHttpError';
    this.statusCode = statusCode;
    this.retryAfter = retryAfter;
  }
}

export default app;

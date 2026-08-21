import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import app, {
  AiProviderHttpError,
  FACT_GENERATION_BATCH_SIZE,
  describeAiProviderFailure,
  generateFactsWithAi,
  makeMockFacts,
  parseAiJsonObject,
  validateGenerateFactsRequest,
} from '../src/app.js';
import { areFactsSimilar } from '../src/fact-deduplicator.js';

let server;
let baseUrl;

before(async () => {
  delete process.env.OPENAI_API_KEY;
  delete process.env.CEREBRAS_API_KEY;
  delete process.env.AI_PROVIDER;
  delete process.env.ALLOW_MOCK_FACTS;
  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  const address = server.address();
  baseUrl = `http://127.0.0.1:${address.port}`;
});

after(async () => {
  await new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
});

test('mock facts require an explicit test flag', async () => {
  const requestBody = {
    topic: 'space',
    language: 'en',
    lengthMode: 'short',
    count: 2,
  };

  const unavailableResponse = await postFacts(requestBody);
  assert.equal(unavailableResponse.status, 503);
  assert.match((await unavailableResponse.json()).error, /not configured/);

  process.env.ALLOW_MOCK_FACTS = 'true';
  try {
    const response = await postFacts(requestBody);
    assert.equal(response.status, 200);
    const body = await response.json();
    assert.equal(body.source, 'mock');
    assert.equal(body.facts.length, 2);
    assert.match(body.facts[0].title, /space/);
    assert.notEqual(body.facts[0].body, body.facts[1].body);
  } finally {
    delete process.env.ALLOW_MOCK_FACTS;
  }
});

test('invalid language is rejected', async () => {
  const response = await fetch(`${baseUrl}/api/generate-facts`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      topic: 'history',
      language: 'de',
      lengthMode: 'short',
      count: 1,
    }),
  });

  assert.equal(response.status, 400);
  const body = await response.json();
  assert.match(body.error, /language/);
});

test('invalid length mode is rejected', async () => {
  const response = await fetch(`${baseUrl}/api/generate-facts`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      topic: 'history',
      language: 'ru',
      lengthMode: 'giant',
      count: 1,
    }),
  });

  assert.equal(response.status, 400);
  const body = await response.json();
  assert.match(body.error, /lengthMode/);
});

test('valid request accepts excluded facts', () => {
  const result = validateGenerateFactsRequest({
    topic: 'animals',
    language: 'en',
    lengthMode: 'short',
    count: 1,
    excludedFacts: [
      {
        title: ' Octopus Hearts ',
        body: ' Octopuses have three hearts. ',
      },
      {
        title: '',
        body: '',
      },
    ],
  });

  assert.equal(result.ok, true);
  assert.deepEqual(result.value.excludedFacts, [
    {
      title: 'Octopus Hearts',
      body: 'Octopuses have three hearts.',
      key: '',
    },
  ]);
});

test('generation defaults to the experimental 10-fact batch size', () => {
  const result = validateGenerateFactsRequest({
    topic: 'Flutter & Dart',
    language: 'en',
    lengthMode: 'medium',
  });

  assert.equal(result.ok, true);
  assert.equal(result.value.count, FACT_GENERATION_BATCH_SIZE);
});

test('special topic names remain valid request values', () => {
  for (const topic of [
    'Flutter & Dart',
    'История Казахстана',
    'Қазақ хандығы',
    'C++',
    'AI / Machine Learning',
  ]) {
    const result = validateGenerateFactsRequest({
      topic,
      language: 'kk',
      lengthMode: 'detailed',
      count: FACT_GENERATION_BATCH_SIZE,
    });
    assert.equal(result.ok, true, topic);
    assert.equal(result.value.topic, topic);
  }
});

test('invalid excluded facts are rejected', () => {
  const result = validateGenerateFactsRequest({
    topic: 'animals',
    language: 'en',
    lengthMode: 'short',
    count: 1,
    excludedFacts: 'Octopus Hearts',
  });

  assert.equal(result.ok, false);
  assert.match(result.error, /excludedFacts/);
});

test('short paraphrases and screenshot variants are duplicates', () => {
  assert.equal(
    areFactsSimilar(
      {
        title: 'Octopus Hearts',
        body: 'Octopuses have three hearts.',
      },
      {
        title: 'Three Hearts',
        body: 'An octopus has three hearts.',
      },
    ),
    true,
  );

  assert.equal(
    areFactsSimilar(
      {
        title: "The Axolotl's Power",
        body:
          'Unlike most amphibians, the axolotl can regenerate entire limbs, heart tissue, and parts of its brain without permanent scars.',
      },
      {
        title: "The Axolotl's Healing Power",
        body:
          'Unlike most animals, axolotls regenerate limbs, spinal cord segments, and parts of their heart and brain without leaving scars.',
      },
    ),
    true,
  );
});

test('different facts about one animal are not duplicates', () => {
  assert.equal(
    areFactsSimilar(
      {
        title: 'Octopus Hearts',
        body: 'Octopuses have three hearts; two pump blood to the gills.',
      },
      {
        title: 'Octopus Blue Blood',
        body:
          'Octopus blood uses copper-rich hemocyanin to carry oxygen in cold water.',
      },
    ),
    false,
  );

  assert.equal(
    areFactsSimilar(
      {
        key: 'octopus',
        title: 'Octopus Blue Blood',
        body: 'Copper-rich hemocyanin makes octopus blood appear blue.',
      },
      {
        key: 'octopus',
        title: 'Distributed Intelligence',
        body: 'Most octopus neurons are located throughout its arms.',
      },
    ),
    false,
  );
});

test('one provider request returns and measures a 10-fact batch', async () => {
  const rawFacts = distinctRawFacts.slice(0, FACT_GENERATION_BATCH_SIZE);
  const fakeProvider = scriptedProvider([
    {
      facts: rawFacts,
      usage: {
        prompt_tokens: 321,
        completion_tokens: 654,
        total_tokens: 975,
      },
    },
  ]);

  const generation = await generateFactsWithAi({
    provider: testProvider,
    topic: 'Space',
    language: 'en',
    lengthMode: 'short',
    count: FACT_GENERATION_BATCH_SIZE,
    targetWords: 20,
    excludedFacts: [],
    fetchImpl: fakeProvider.fetch,
    logger: quietLogger,
  });

  assert.equal(fakeProvider.requests.length, 1);
  assert.equal(generation.facts.length, FACT_GENERATION_BATCH_SIZE);
  assert.equal(generation.facts[0].body, rawFacts[0].content);
  assert.deepEqual(generation.metrics.usage, {
    inputTokens: 321,
    outputTokens: 654,
    totalTokens: 975,
  });
  assert.equal(generation.metrics.providerRequests, 1);
  assert.match(
    fakeProvider.requests[0].messages[1].content,
    /Generate exactly 10 facts in the single facts array/,
  );
  assert.equal(fakeProvider.requests[0].max_completion_tokens, 7600);
});

test('partial batches are accepted without a refill request', async () => {
  const fakeProvider = scriptedProvider([
    {
      facts: distinctRawFacts.slice(0, FACT_GENERATION_BATCH_SIZE - 1),
    },
  ]);
  const warnings = [];
  const generation = await generateFactsWithAi({
    provider: testProvider,
    topic: 'Flutter & Dart',
    language: 'en',
    lengthMode: 'medium',
    count: FACT_GENERATION_BATCH_SIZE,
    targetWords: 40,
    excludedFacts: [],
    fetchImpl: fakeProvider.fetch,
    logger: { ...quietLogger, warn: (message) => warnings.push(message) },
  });

  assert.equal(fakeProvider.requests.length, 1);
  assert.equal(generation.facts.length, FACT_GENERATION_BATCH_SIZE - 1);
  assert.equal(generation.metrics.receivedFacts, FACT_GENERATION_BATCH_SIZE - 1);
  assert.match(warnings[0], /Expected 10 facts but accepted 9/);
});

test('invalid and duplicate fact objects are removed without splitting text', async () => {
  const fakeProvider = scriptedProvider([
    {
      facts: [
        {
          key: 'sun|star',
          title: 'The Sun Is a Star',
          content: 'The Sun is a star at the center of the Solar System.',
        },
        {
          key: 'sun|star',
          title: 'Our Star',
          content: 'The Sun is actually a star at the center of our Solar System.',
        },
        { title: 42, content: 'Wrong title type.' },
        { title: 'Missing content' },
      ],
    },
  ]);
  const generation = await generateFactsWithAi({
    provider: testProvider,
    topic: 'Space',
    language: 'en',
    lengthMode: 'short',
    count: 4,
    targetWords: 20,
    excludedFacts: [],
    fetchImpl: fakeProvider.fetch,
    logger: quietLogger,
  });

  assert.equal(generation.facts.length, 1);
  assert.equal(generation.metrics.duplicatesRemoved, 1);
  assert.equal(generation.metrics.invalidFactsRemoved, 2);
  assert.equal(fakeProvider.requests.length, 1);
});

test('JSON parser accepts whitespace, a complete fence, or one trailing period', () => {
  const parsed = parseAiJsonObject(
    '  ```json\n{"facts":[{"title":"A","content":"B"}]}\n```  ',
  );
  assert.equal(parsed.facts[0].content, 'B');
  assert.deepEqual(parseAiJsonObject('{"facts":[]}.').facts, []);
  assert.throws(
    () => parseAiJsonObject('Explanation: {"facts":[]}'),
    /not valid JSON/,
  );
});

test('malformed provider JSON fails cleanly after one request', async () => {
  const errors = [];
  let requests = 0;
  await assert.rejects(
    generateFactsWithAi({
      provider: testProvider,
      topic: 'Қазақ хандығы',
      language: 'kk',
      lengthMode: 'detailed',
      count: FACT_GENERATION_BATCH_SIZE,
      targetWords: 70,
      excludedFacts: [],
      fetchImpl: async () => {
        requests += 1;
        return providerResponse('{"facts":[', null);
      },
      logger: { ...quietLogger, error: (...values) => errors.push(values) },
    }),
    /not valid JSON/,
  );

  assert.equal(requests, 1);
  assert.equal(errors.length, 1);
});

test('mock generator labels every explicit mock response uniquely', () => {
  const facts = makeMockFacts({
    topic: 'Animals',
    language: 'en',
    lengthMode: 'short',
    count: 3,
  });

  assert.equal(facts.length, 3);
  assert.equal(new Set(facts.map((fact) => fact.body)).size, 3);
  assert.ok(facts.every((fact) => fact.body.startsWith('[Mock')));
});

test('upstream rate limits stay distinguishable from bad AI content', async () => {
  let requests = 0;
  await assert.rejects(
    generateFactsWithAi({
      provider: testProvider,
      topic: 'Animals',
      language: 'en',
      lengthMode: 'short',
      count: 1,
      targetWords: 20,
      excludedFacts: [],
      fetchImpl: async () => {
        requests += 1;
        return new Response(
          JSON.stringify({ message: 'token quota exceeded' }),
          { status: 429, headers: { 'Retry-After': '60' } },
        );
      },
      logger: quietLogger,
    }),
    (error) =>
      error instanceof AiProviderHttpError &&
      error.statusCode === 429 &&
      error.retryAfter === '60',
  );
  assert.equal(requests, 1);
});

test('provider payment errors are safe and remain distinguishable', () => {
  const rawProviderMessage = JSON.stringify({
    message: 'Payment required to access this resource. Visit billing.',
    type: 'payment_required_error',
    code: 'payment_required',
  });
  const failure = describeAiProviderFailure(
    new AiProviderHttpError('cerebras', 402, rawProviderMessage),
  );

  assert.deepEqual(failure, {
    statusCode: 402,
    code: 'provider_payment_required',
    message: 'AI provider billing or quota is unavailable',
    retryAfter: null,
  });
  assert.doesNotMatch(failure.message, /Visit billing|payment_required_error/);
});

test('provider authentication details are not exposed to clients', () => {
  const failure = describeAiProviderFailure(
    new AiProviderHttpError('cerebras', 401, 'invalid key ending in secret'),
  );

  assert.equal(failure.statusCode, 502);
  assert.equal(failure.code, 'provider_authentication_failed');
  assert.doesNotMatch(failure.message, /secret|invalid key/);
});

const testProvider = {
  name: 'test',
  apiKey: 'not-a-real-key',
  baseUrl: 'https://provider.invalid/v1',
  model: 'test-model',
  supportsJsonMode: true,
  maxCompletionTokens: 7600,
};

const quietLogger = {
  info() {},
  warn() {},
  error() {},
};

const distinctRawFacts = [
  { key: 'mercury|year', title: 'Mercury Year', content: 'Mercury completes an orbit around the Sun in only 88 Earth days.' },
  { key: 'venus|rotation', title: 'Venus Rotation', content: 'Venus rotates so slowly that one rotation lasts longer than its orbital year.' },
  { key: 'earth|tectonics', title: 'Moving Plates', content: 'Earth recycles crust through active plate tectonics and subduction zones.' },
  { key: 'mars|olympus mons', title: 'Olympus Mons', content: 'Mars hosts Olympus Mons, the tallest known volcano in the Solar System.' },
  { key: 'jupiter|magnetosphere', title: 'Jupiter Magnetism', content: 'Jupiter has the strongest planetary magnetic field in the Solar System.' },
  { key: 'saturn|density', title: 'Saturn Density', content: 'Saturn has a lower average density than liquid water.' },
  { key: 'uranus|axial tilt', title: 'Sideways Uranus', content: 'Uranus spins with an axial tilt of about 98 degrees.' },
  { key: 'neptune|winds', title: 'Neptune Winds', content: 'Neptune has winds that can exceed two thousand kilometers per hour.' },
  { key: 'moon|recession', title: 'Receding Moon', content: 'The Moon moves away from Earth by roughly four centimeters each year.' },
  { key: 'sun|mass', title: 'Solar Mass', content: 'The Sun contains more than 99 percent of the Solar System mass.' },
  { key: 'black hole|time', title: 'Gravity and Time', content: 'Strong gravity near a black hole makes clocks run slower relative to distant observers.' },
  { key: 'pulsar|rotation', title: 'Pulsar Clocks', content: 'Some pulsars rotate hundreds of times every second with remarkable regularity.' },
  { key: 'comet|tail', title: 'Comet Tails', content: 'A comet tail points generally away from the Sun because of radiation and solar wind.' },
  { key: 'nebula|stars', title: 'Stellar Nurseries', content: 'Dense regions inside nebulae can collapse to form new stars.' },
  { key: 'exoplanet|transit', title: 'Transit Detection', content: 'Astronomers discover exoplanets by measuring tiny periodic dips in a star brightness.' },
];

function scriptedProvider(responses) {
  const queue = [...responses];
  const requests = [];
  return {
    requests,
    fetch: async (_url, options) => {
      requests.push(JSON.parse(options.body));
      const scripted = queue.shift();
      assert.ok(scripted, 'The fake provider received an unexpected request');
      return providerResponse(
        JSON.stringify({ facts: scripted.facts }),
        scripted.usage,
      );
    },
  };
}

function providerResponse(content, usage) {
  return new Response(
    JSON.stringify({
      choices: [{ message: { content } }],
      ...(usage ? { usage } : {}),
    }),
    {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    },
  );
}

function postFacts(body) {
  return fetch(`${baseUrl}/api/generate-facts`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

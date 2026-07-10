import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import app, {
  AiProviderHttpError,
  generateFactsWithAi,
  makeMockFacts,
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

test('generation retries when the provider only returns an old claim', async () => {
  const excluded = {
    key: 'octopus|three hearts',
    title: 'Octopus Hearts',
    body:
      'Octopuses have three hearts: two pump blood to the gills and one supplies the body.',
  };
  const duplicate = {
    key: 'octopus|three cardiac organs',
    title: 'A Trio of Cardiac Organs',
    body:
      'An octopus uses a trio of cardiac organs; a pair serves the gills and one serves the body.',
  };
  const fresh = {
    key: 'wombat|cube droppings',
    title: 'Wombat Cubes',
    body:
      'Wombats produce cube-shaped droppings because different parts of their intestines stretch at different rates.',
  };
  const fakeProvider = scriptedProvider([[duplicate], [fresh]]);

  const facts = await generateFactsWithAi({
    provider: testProvider,
    topic: 'Animals',
    language: 'en',
    lengthMode: 'short',
    count: 1,
    targetWords: 20,
    excludedFacts: [excluded],
    fetchImpl: fakeProvider.fetch,
  });

  assert.deepEqual(facts, [fresh]);
  assert.equal(fakeProvider.requests.length, 2);
  const retryPrompt = fakeProvider.requests[1].messages[1].content;
  assert.match(retryPrompt, /A Trio of Cardiac Organs/);
  assert.match(retryPrompt, /a trio of cardiac organs/);
  assert.match(retryPrompt, /Novelty attempt: 2/);
});

test('six short generations do not cycle back to the first claim', async () => {
  const firstFive = [
    {
      key: 'octopus|three hearts',
      title: 'Octopus Hearts',
      body: 'Octopuses have three hearts; two pump to the gills.',
    },
    {
      key: 'axolotl|limb regeneration',
      title: 'Axolotl Regeneration',
      body: 'Axolotls can regrow limbs, spinal cord tissue, and parts of organs.',
    },
    {
      key: 'mantis shrimp|vision',
      title: 'Mantis Shrimp Vision',
      body: 'Mantis shrimp have far more types of color receptors than humans.',
    },
    {
      key: 'wombat|cube droppings',
      title: 'Wombat Cubes',
      body: 'Wombat intestines shape their droppings into cubes.',
    },
    {
      key: 'crow|tool use',
      title: 'Crow Tools',
      body: 'New Caledonian crows shape twigs into tools for extracting insects.',
    },
  ];
  const repeatedFirst = {
    key: 'octopus|three cardiac organs',
    title: 'A Trio of Cardiac Organs',
    body: 'An octopus has a trio of cardiac organs, including a pair for its gills.',
  };
  const sixth = {
    key: 'sea otter|stone tools',
    title: 'Sea Otter Tools',
    body: 'Sea otters use stones as anvils to crack hard-shelled prey.',
  };
  const responses = [
    ...firstFive.map((fact) => [fact]),
    [repeatedFirst],
    [sixth],
  ];
  const fakeProvider = scriptedProvider(responses);
  const history = [];

  for (let index = 0; index < 6; index += 1) {
    const generated = await generateFactsWithAi({
      provider: testProvider,
      topic: 'Animals',
      language: 'en',
      lengthMode: 'short',
      count: 1,
      targetWords: 20,
      excludedFacts: history,
      fetchImpl: fakeProvider.fetch,
    });
    history.push(...generated);
  }

  assert.equal(history.length, 6);
  assert.equal(history.at(-1).title, sixth.title);
  for (let first = 0; first < history.length; first += 1) {
    for (let second = first + 1; second < history.length; second += 1) {
      assert.equal(
        areFactsSimilar(history[first], history[second]),
        false,
        `${history[first].title} repeated as ${history[second].title}`,
      );
    }
  }
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
  await assert.rejects(
    generateFactsWithAi({
      provider: testProvider,
      topic: 'Animals',
      language: 'en',
      lengthMode: 'short',
      count: 1,
      targetWords: 20,
      excludedFacts: [],
      fetchImpl: async () => new Response(
        JSON.stringify({ message: 'token quota exceeded' }),
        { status: 429 },
      ),
    }),
    (error) =>
      error instanceof AiProviderHttpError && error.statusCode === 429,
  );
});

const testProvider = {
  name: 'test',
  apiKey: 'not-a-real-key',
  baseUrl: 'https://provider.invalid/v1',
  model: 'test-model',
  supportsJsonMode: true,
};

function scriptedProvider(responses) {
  const queue = [...responses];
  const requests = [];
  return {
    requests,
    fetch: async (_url, options) => {
      requests.push(JSON.parse(options.body));
      const facts = queue.shift();
      assert.ok(facts, 'The fake provider received an unexpected request');
      return new Response(
        JSON.stringify({
          choices: [
            {
              message: {
                content: JSON.stringify({ facts }),
              },
            },
          ],
        }),
        {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        },
      );
    },
  };
}

function postFacts(body) {
  return fetch(`${baseUrl}/api/generate-facts`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

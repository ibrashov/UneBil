import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import app from '../src/app.js';

let server;
let baseUrl;

before(async () => {
  delete process.env.OPENAI_API_KEY;
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

test('valid request returns mock facts without an API key', async () => {
  const response = await fetch(`${baseUrl}/api/generate-facts`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      topic: 'space',
      language: 'en',
      lengthMode: 'short',
      count: 2,
    }),
  });

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.source, 'mock');
  assert.equal(body.facts.length, 2);
  assert.match(body.facts[0].title, /space/);
  assert.ok(body.facts[0].body.length > 20);
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

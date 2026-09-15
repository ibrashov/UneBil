// Explicit live smoke check: one real provider request per language.
import '../src/env.js';
import app from '../src/app.js';

const args = process.argv.slice(2);
let server;
try {
  let baseUrl = args.find((arg) => !arg.startsWith('--')) || 'http://127.0.0.1:3000';
  if (args.includes('--local')) {
    server = app.listen(0, '127.0.0.1');
    await new Promise((resolve) => server.once('listening', resolve));
    baseUrl = `http://127.0.0.1:${server.address().port}`;
  }
  baseUrl = baseUrl.replace(/\/+$/, '');
  const health = await fetch(`${baseUrl}/health`, { signal: AbortSignal.timeout(90000) });
  if (!health.ok || (await health.json()).ok !== true) throw new Error('Backend health check failed');
  console.log(`Backend reachable: ${baseUrl}`);
  for (const language of args.includes('--all-languages') ? ['en', 'ru', 'kk'] : ['en']) {
    const response = await fetch(`${baseUrl}/api/generate-facts`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ topic: 'Space', language, lengthMode: 'detailed', count: 10 }),
      signal: AbortSignal.timeout(70000),
    });
    const result = await response.json();
    if (!response.ok) throw new Error(`HTTP ${response.status}: ${result.code || result.error}`);
    if (result.source === 'mock' || !result.facts?.length ||
        result.facts.some((fact) => !fact.title?.trim() || !fact.body?.trim())) {
      throw new Error('Backend did not return real, usable facts');
    }
    console.log(JSON.stringify({ language, source: result.source, facts: result.facts.length, generation: result.generation }));
  }
} catch (error) {
  console.error(`AI check failed: ${error.message}`);
  process.exitCode = 1;
} finally {
  server?.close();
}

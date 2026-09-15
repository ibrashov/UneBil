import './env.js';
import app, { getAiProviderConfig } from './app.js';

const port = Number(process.env.PORT || 3000);
const host = process.env.HOST || '0.0.0.0';

app.listen(port, host, () => {
  console.log(`UneBil backend listening on http://${host}:${port}`);
  const provider = getAiProviderConfig();
  if (!provider || provider.error) {
    console.error(`[FactGeneration] ${provider?.error || 'AI provider is not configured'}`);
  } else {
    console.log(`[FactGeneration] Provider: ${provider.name}; model: ${provider.model}`);
  }
});

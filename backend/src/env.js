import { loadEnvFile } from 'node:process';
import { fileURLToPath } from 'node:url';

// Resolve beside the backend, so IDE launches from the repository root work too.
// Existing environment variables (including Render secrets) take precedence.
try {
  loadEnvFile(fileURLToPath(new URL('../.env', import.meta.url)));
} catch (error) {
  if (error.code !== 'ENOENT') throw error;
}

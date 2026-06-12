import Ajv2020 from 'ajv/dist/2020.js';
import addFormats from 'ajv-formats';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');

const schema = JSON.parse(readFileSync(resolve(root, 'local-control.schema.json'), 'utf8'));
const ajv = new Ajv2020({ strict: false, allErrors: true });
addFormats(ajv);
const validate = ajv.compile(schema);

const dir = resolve(root, 'mock', 'local-control');
let failed = 0;
for (const file of readdirSync(dir).filter(f => f.endsWith('.json'))) {
  const data = JSON.parse(readFileSync(resolve(dir, file), 'utf8'));
  if (validate(data)) { console.log(`ok   local-control/${file}`); }
  else { console.error(`FAIL local-control/${file}`); console.error(validate.errors); failed++; }
}
process.exit(failed ? 1 : 0);

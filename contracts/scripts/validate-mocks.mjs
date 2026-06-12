import RefParser from '@apidevtools/json-schema-ref-parser';
import Ajv2020 from 'ajv/dist/2020.js';
import addFormats from 'ajv-formats';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import YAML from 'yaml';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');

// mock file (under contracts/mock/) -> component schema name it must satisfy
const manifest = {
  'user.json': 'User',
  'token-pair.json': 'TokenPair',
  'subscription.json': 'Subscription',
  'device.json': 'Device',
  'device-list.json': 'DeviceList',
  'node-list.json': 'NodeList',
  'select-best.json': 'SelectBestResponse',
};

const api = YAML.parse(readFileSync(resolve(root, 'backend-api.openapi.yaml'), 'utf8'));
const deref = await RefParser.dereference(api);
const schemas = deref.components?.schemas ?? {};

const ajv = new Ajv2020({ strict: false, allErrors: true });
addFormats(ajv);

let failed = 0;
for (const [file, schemaName] of Object.entries(manifest)) {
  const schema = schemas[schemaName];
  if (!schema) { console.error(`MISSING SCHEMA: ${schemaName} for ${file}`); failed++; continue; }
  const data = JSON.parse(readFileSync(resolve(root, 'mock', file), 'utf8'));
  const validate = ajv.compile(schema);
  if (validate(data)) { console.log(`ok   ${file} -> ${schemaName}`); }
  else { console.error(`FAIL ${file} -> ${schemaName}`); console.error(validate.errors); failed++; }
}
if (Object.keys(manifest).length === 0) console.log('(no mocks registered yet)');
process.exit(failed ? 1 : 0);

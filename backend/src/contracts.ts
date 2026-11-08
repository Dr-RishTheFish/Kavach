// Compiles the canonical JSON Schemas in shared/contracts/ so runtime validation and the
// published contract cannot drift. Validator: Ajv 8 (JSON Schema draft 2020-12) + ajv-formats.
import { readFileSync } from 'node:fs';
import { Ajv2020 } from 'ajv/dist/2020.js';
import addFormatsModule from 'ajv-formats';

const addFormats = addFormatsModule as unknown as (ajv: Ajv2020) => Ajv2020;
const contractsDir = new URL('../../shared/contracts/', import.meta.url);
const load = (file: string): object => JSON.parse(readFileSync(new URL(file, contractsDir), 'utf8'));

const ajv = new Ajv2020({ allErrors: true, strict: true, strictRequired: false });
addFormats(ajv);

export const validators = {
  analyzeRequest: ajv.compile(load('analyze-request.schema.json')),
  riskAssessment: ajv.compile(load('risk-assessment.schema.json')),
  health: ajv.compile(load('health.schema.json')),
  error: ajv.compile(load('error.schema.json')),
};

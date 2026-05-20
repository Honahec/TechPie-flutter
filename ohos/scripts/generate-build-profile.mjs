#!/usr/bin/env node
// Generate ohos/build-profile.json5 from the committed template + OHOS_* env vars.
// Run automatically by hvigorfile.ts on every hvigor invocation; can also be invoked
// directly via `node ohos/scripts/generate-build-profile.mjs`.

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const ohosDir = resolve(here, '..');
const templatePath = resolve(ohosDir, 'build-profile.template.json5');
const outputPath = resolve(ohosDir, 'build-profile.json5');

const REQUIRED = [
  'OHOS_CERT_PATH',
  'OHOS_STORE_PASSWORD',
  'OHOS_KEY_ALIAS',
  'OHOS_KEY_PASSWORD',
  'OHOS_PROFILE_PATH',
  'OHOS_SIGN_ALG',
  'OHOS_STORE_FILE',
];

function generate() {
  if (!existsSync(templatePath)) {
    throw new Error(`Template not found: ${templatePath}`);
  }

  const missing = REQUIRED.filter((k) => !process.env[k]);
  if (missing.length === REQUIRED.length) {
    // No signing env at all — likely a contributor without signing material.
    // Leave any existing build-profile.json5 alone so DevEco's automatic signing
    // (or a previously generated file) can still be used.
    if (existsSync(outputPath)) return;
    throw new Error(
      `No OHOS_* signing env vars set and ${outputPath} does not exist. ` +
        `Source .envrc (direnv) or copy .envrc.example, fill in the values, then retry.`,
    );
  }
  if (missing.length > 0) {
    throw new Error(
      `Missing required OHOS signing env vars: ${missing.join(', ')}. ` +
        `See .envrc.example.`,
    );
  }

  let content = readFileSync(templatePath, 'utf8');
  for (const key of REQUIRED) {
    content = content.replaceAll(`__${key}__`, process.env[key]);
  }
  writeFileSync(outputPath, content);
}

try {
  generate();
} catch (err) {
  console.error(`[generate-build-profile] ${err.message}`);
  process.exit(1);
}

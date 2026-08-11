#!/usr/bin/env node
// 原稿から語彙トークンを取り出し、1 行 1 語で標準出力へ書く。
// scripts/update-vocabulary.sh が使う。切り出しは lib-vocabulary.mjs と共有する。

import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { tokensOf, walkMarkdown } from './lib-vocabulary.mjs';

const ROOT = new URL('../../', import.meta.url).pathname;

const all = new Set();
for (const file of walkMarkdown(join(ROOT, 'manuscript'))) {
  for (const t of tokensOf(readFileSync(file, 'utf8'))) all.add(t);
}
console.log([...all].sort().join('\n'));

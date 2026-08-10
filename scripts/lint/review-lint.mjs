#!/usr/bin/env node
// 散文レビュー台帳の検査。規約が進んだのに原稿が取り残される状態を落とす。
//
// 原稿は書いた時点の規約で固定される。規約は指摘のたびに増える。この 2 つがずれると、
// 読者が次に開いた章が「現行規約での初読」になり、同じ種類の指摘が章ごとに出る。
// 実際、全 27 章は規約 8〜15 条の時点で書かれ、その後 38 条まで増えた。
//
// 検査 1: docs/prose-review-log.md に全章の行があること
// 検査 2: 各章の規約版が WRITING_GUIDELINES.md の現行版と一致すること

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative, basename } from 'node:path';

const ROOT = new URL('../../', import.meta.url).pathname;
const GUIDELINES = join(ROOT, 'WRITING_GUIDELINES.md');
const LEDGER = join(ROOT, 'docs/prose-review-log.md');

const versionMatch = readFileSync(GUIDELINES, 'utf8').match(/^規約版:\s*(\d+)\s*$/m);
if (!versionMatch) {
  console.error('WRITING_GUIDELINES.md に「規約版: N」の行がない');
  process.exit(1);
}
const current = parseInt(versionMatch[1], 10);

function walk(dir) {
  const out = [];
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry);
    if (statSync(p).isDirectory()) out.push(...walk(p));
    else if (entry.endsWith('.md')) out.push(p);
  }
  return out;
}

const chapters = walk(join(ROOT, 'manuscript'))
  .map((f) => relative(ROOT, f))
  .sort();

const ledger = readFileSync(LEDGER, 'utf8');
const rows = new Map();
for (const line of ledger.split('\n')) {
  const m = line.match(/^\|\s*\[[^\]]+\]\(\.\.\/([^)]+)\)\s*\|\s*(\d+)\s*\|/);
  if (m) rows.set(m[1], parseInt(m[2], 10));
}

const errors = [];
for (const ch of chapters) {
  if (!rows.has(ch)) {
    errors.push(`${ch}: 台帳に行がない。docs/prose-review-log.md に追加する`);
    continue;
  }
  const v = rows.get(ch);
  if (v !== current) {
    errors.push(
      `${ch}: 台帳の規約版が ${v}、現行は ${current}。現行の規約で読み直してから版を更新する`,
    );
  }
}
for (const f of rows.keys()) {
  if (!chapters.includes(f)) errors.push(`${f}: 台帳にあるが原稿に存在しない`);
}

if (errors.length > 0) {
  console.error('散文レビュー台帳の違反:');
  for (const e of errors.slice(0, 40)) console.error(`  - ${e}`);
  process.exit(1);
}
console.log(`散文レビュー台帳 OK (規約版 ${current} / ${chapters.length} 章)`);

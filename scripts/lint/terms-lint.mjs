#!/usr/bin/env node
// 未定義語の検査。散文の規則は破られた実績があるため（RP・ARM・Bicep・platform で計 4 回）、
// 「初出章より前で使わない」を機械検査にする。
//
// 検査 1: docs/glossary.json の語を、初出章より前の章の本文で使ったら落とす
// 検査 2: 大文字 2〜6 文字の略語らしきトークンが、許可リストにも用語集にもなければ落とす
// コードフェンス内は対象外（コマンドと実出力は実物を尊重する）。

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative, basename } from 'node:path';

const ROOT = new URL('../../', import.meta.url).pathname;
const glossary = JSON.parse(readFileSync(join(ROOT, 'docs/glossary.json'), 'utf8'));
const TERMS = glossary.terms;
const CAPS_OK = new Set(glossary.capsAllowlist);

function chapterOf(file) {
  const b = basename(file);
  const m = b.match(/^(\d{2})-/);
  if (m) return parseInt(m[1], 10);
  return 99; // 付録は最後（すべての語が使える）
}

function walk(dir) {
  const out = [];
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry);
    if (statSync(p).isDirectory()) out.push(...walk(p));
    else if (entry.endsWith('.md')) out.push(p);
  }
  return out;
}

const errors = [];

for (const file of walk(join(ROOT, 'manuscript')).sort()) {
  const rel = relative(ROOT, file);
  const chapter = chapterOf(file);
  const lines = readFileSync(file, 'utf8').split('\n');
  let inFence = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (/^\s*```/.test(line)) { inFence = !inFence; continue; }
    if (inFence) continue;
    // インラインコードも対象外にする
    const prose = line.replace(/`[^`]*`/g, '');

    // 「第N章」への言及がある行は、導入済みの前方参照として語の検査を免除する
    const hasForwardRef = /第\s*\d+\s*章/.test(prose);
    for (const [term, def] of Object.entries(TERMS)) {
      if (def <= chapter) continue;
      if (hasForwardRef) continue;
      if (prose.includes(term)) {
        errors.push(`${rel}:${i + 1}: "${term}" は第${def}章が初出。ここ（第${chapter}章）で使うなら先に導入する`);
      }
    }

    for (const m of prose.matchAll(/(?<![A-Za-z])([A-Z]{2,6})(?![a-z])/g)) {
      const token = m[1];
      if (CAPS_OK.has(token)) continue;
      if (Object.keys(TERMS).some((t) => t.includes(token) && TERMS[t] <= chapter)) continue;
      errors.push(`${rel}:${i + 1}: 略語 "${token}" が用語集にも許可リストにもない。定義するか glossary.json へ`);
    }
  }
}

if (errors.length > 0) {
  console.error('用語規約の違反:');
  for (const e of [...new Set(errors)].slice(0, 40)) console.error(`  - ${e}`);
  process.exit(1);
}
console.log('用語規約 OK');

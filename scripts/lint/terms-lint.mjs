#!/usr/bin/env node
// 未定義語の検査。散文の規則は破られた実績があるため（RP・ARM・Bicep・platform で計 4 回）、
// 「初出章より前で使わない」を機械検査にする。
//
// 検査 1: docs/glossary.json の語を、初出章より前の章の本文で使ったら落とす
// 検査 2: 大文字 2〜6 文字の略語らしきトークンが、許可リストにも用語集にもなければ落とす
// 検査 3: 図のラベルに出る英語の固有名（ロール名・サービス名）が、読者がまだ見ていない語なら落とす
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

// 図のラベルに出る英語の固有名。大文字始まりの語が 2 つ以上連なるもの（ロール名・サービス名）を拾う。
// 日本語の複合語は拾わない。「発行」「参照」のような普通の語まで落として lint が信用を失うため。
const PROPER_NOUN = /\b[A-Z][A-Za-z0-9]*(?:\s+[A-Z][A-Za-z0-9]*)+\b/g;

// mermaid の 1 行からラベルを取り出す。引用済みラベルと、括弧内の素のラベルの両方。
function mermaidLabels(line) {
  const out = [];
  for (const m of line.matchAll(/"([^"]+)"/g)) out.push(m[1]);
  const bare = line.replace(/"[^"]*"/g, '');
  for (const m of bare.matchAll(/[[({]{1,2}([^[\](){}|]+)[\])}]{1,2}/g)) out.push(m[1]);
  return out;
}

// フェンスの外の本文だけを連結する。読者が実際に読んだ説明の集合。
function proseOf(lines, until = Infinity) {
  const out = [];
  let inFence = false;
  for (let i = 0; i < Math.min(lines.length, until); i++) {
    if (/^\s*```/.test(lines[i])) {
      inFence = !inFence;
      continue;
    }
    if (!inFence) out.push(lines[i]);
  }
  return out.join('\n');
}

const files = walk(join(ROOT, 'manuscript')).sort();

// 章ごとの本文。前の章までに読者が目にした語を引くために使う。
const proseByChapter = new Map();
for (const file of files) {
  const ch = chapterOf(file);
  const text = proseOf(readFileSync(file, 'utf8').split('\n'));
  proseByChapter.set(ch, (proseByChapter.get(ch) ?? '') + '\n' + text);
}

for (const file of files) {
  const rel = relative(ROOT, file);
  const chapter = chapterOf(file);
  const lines = readFileSync(file, 'utf8').split('\n');
  let inFence = false;

  // 図のラベルの検査。読者は前の章を読んでいるものとし、
  // 「前の章の本文」「この図より前の同章本文」「用語集で初出章がこの章以前」のどれかを求める。
  const earlier = [...proseByChapter.entries()]
    .filter(([ch]) => ch < chapter)
    .map(([, t]) => t)
    .join('\n');
  const allowedTerms = Object.entries(TERMS)
    .filter(([, def]) => def <= chapter)
    .map(([t]) => t);
  const capsWords = new Set([...CAPS_OK, ...allowedTerms.flatMap((t) => t.split(/\s+/))]);

  for (let i = 0; i < lines.length; i++) {
    if (!/^\s*```mermaid\s*$/.test(lines[i])) continue;
    const start = i;
    let end = i + 1;
    while (end < lines.length && !/^\s*```\s*$/.test(lines[end])) end++;
    const before = proseOf(lines, start);

    for (let j = start + 1; j < end; j++) {
      for (const label of mermaidLabels(lines[j])) {
        for (const phrase of label.match(PROPER_NOUN) ?? []) {
          if (before.includes(phrase) || earlier.includes(phrase)) continue;
          if (allowedTerms.some((t) => t.includes(phrase))) continue;
          // 既知の語の組み合わせ（ARM JSON など）は、語ごとに既知なら通す
          if (phrase.split(/\s+/).every((w) => capsWords.has(w) || before.includes(w) || earlier.includes(w))) continue;
          errors.push(
            `${rel}:${j + 1}: 図のラベルの "${phrase}" は読者がまだ見ていない語。図より前の本文で導入する`,
          );
        }
      }
    }
    i = end;
  }


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

    for (const banned of glossary.bannedPhrases || []) {
      if (prose.includes(banned)) {
        errors.push(`${rel}:${i + 1}: 禁止語 "${banned}"。平易な言葉で書き直す`);
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

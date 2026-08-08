#!/usr/bin/env node
// Mermaid フェンスの記法を検査する。
// 検査対象は WRITING_GUIDELINES.md の「4. Mermaid の規約」のうち、GitHub 上で実際に描画が
// 壊れる点に絞る。全ラベルの引用を必須にすると edge label や classDef で誤検出が出るため、
// 「括弧を含むラベルが引用されていない」ケースだけを落とす。

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const ROOT = new URL('../../', import.meta.url).pathname;

const ALLOWED_TYPES = [
  'flowchart',
  'graph',
  'sequenceDiagram',
  'stateDiagram-v2',
  'erDiagram',
  'classDiagram',
];

// ノード定義の開き括弧と、対応する閉じ括弧。長いものから試す。
const DELIMS = [
  ['[[', ']]'],
  ['[(', ')]'],
  ['((', '))'],
  ['{{', '}}'],
  ['[', ']'],
  ['(', ')'],
  ['{', '}'],
];

const PAREN = /[()（）]/;
const LINK = /-->|---|-\.-|==>|===|--|~~~/;

/**
 * 1 行から「ノード定義のラベル」を取り出す。
 * ラベルが `"` で始まる場合は引用済みとして扱い、閉じ引用符まで一気に読み飛ばす。
 * 引用されていない場合は、閉じ括弧かリンク演算子の手前までをラベルとみなす。
 */
function extractLabels(line) {
  const out = [];
  let i = 0;
  while (i < line.length) {
    let opener = null;
    let closer = null;
    for (const [o, c] of DELIMS) {
      if (line.startsWith(o, i)) {
        opener = o;
        closer = c;
        break;
      }
    }
    if (!opener) {
      i++;
      continue;
    }
    // 開き括弧の直前が識別子でなければノード定義ではない
    const before = line.slice(0, i).trimEnd();
    if (!/[A-Za-z0-9_぀-ヿ一-鿿-]$/.test(before)) {
      i += opener.length;
      continue;
    }
    let j = i + opener.length;
    while (j < line.length && line[j] === ' ') j++;

    if (line[j] === '"') {
      const end = line.indexOf('"', j + 1);
      if (end === -1) {
        out.push({ id: before.split(/[\s;]/).pop(), opener, label: line.slice(j), quoted: false });
        break;
      }
      i = end + 1;
      continue;
    }

    // 引用されていないラベル。閉じ括弧かリンク演算子の手前まで。
    let rest = line.slice(j);
    const closeAt = rest.lastIndexOf(closer);
    const linkAt = rest.search(LINK);
    let end = rest.length;
    if (closeAt !== -1) end = Math.min(end, closeAt);
    if (linkAt !== -1) end = Math.min(end, linkAt);
    const label = rest.slice(0, end);
    out.push({ id: before.split(/[\s;]/).pop(), opener, label, quoted: false });
    i = j + end;
  }
  return out;
}

const errors = [];

function walk(dir) {
  const out = [];
  for (const entry of readdirSync(dir)) {
    if (entry === 'node_modules' || entry.startsWith('.')) continue;
    const p = join(dir, entry);
    if (statSync(p).isDirectory()) out.push(...walk(p));
    else if (entry.endsWith('.md')) out.push(p);
  }
  return out;
}

let blockCount = 0;

for (const file of walk(ROOT)) {
  const rel = relative(ROOT, file);
  const lines = readFileSync(file, 'utf8').split('\n');

  let inBlock = false;
  let blockStart = 0;
  let sawType = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    if (!inBlock && /^\s*```mermaid\s*$/.test(line)) {
      inBlock = true;
      blockStart = i + 1;
      sawType = false;
      blockCount++;
      continue;
    }
    if (inBlock && /^\s*```\s*$/.test(line)) {
      if (!sawType) errors.push(`${rel}:${blockStart}: 図種の宣言がない`);
      inBlock = false;
      continue;
    }
    if (!inBlock) continue;

    const trimmed = line.trim();
    if (trimmed === '') continue;
    if (trimmed.startsWith('%%')) {
      if (trimmed.startsWith('%%{')) errors.push(`${rel}:${i + 1}: init ディレクティブは使わない`);
      continue;
    }

    if (!sawType) {
      const type = trimmed.split(/[\s;]/)[0];
      if (!ALLOWED_TYPES.includes(type)) {
        errors.push(`${rel}:${i + 1}: 図種 "${type}" は GitHub でのレンダリングを保証しない`);
      }
      sawType = true;
      continue;
    }

    for (const { id, opener, label } of extractLabels(trimmed)) {
      if (!PAREN.test(label)) continue;
      errors.push(`${rel}:${i + 1}: 括弧を含むラベルは "" で囲む -> ${id}${opener}${label}`);
    }
  }

  if (inBlock) errors.push(`${rel}:${blockStart}: mermaid フェンスが閉じていない`);
}

if (errors.length > 0) {
  console.error('Mermaid 記法の違反:');
  for (const e of errors) console.error(`  - ${e}`);
  process.exit(1);
}
console.log(`Mermaid 記法 OK (${blockCount} 図)`);

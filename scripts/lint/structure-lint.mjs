#!/usr/bin/env node
// 章構成の規約を機械検査する。WRITING_GUIDELINES.md の「2. Part 4 の 6 ブロックの型」と
// 「3. 全章共通の構造」に対応する。規約を散文の申し合わせで終わらせないための CI ゲート。

import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const ROOT = new URL('../../', import.meta.url).pathname;
const MANUSCRIPT = join(ROOT, 'manuscript');

// Part 4 が持つべき H2 見出し。順序も検査する。
const PART4_BLOCKS = [
  '1. このサービスは何のためにあるか',
  '2. 縦の依存関係',
  '3. 横の繋がり ― 認証認可',
  '4. 横の繋がり ― インフラ足回りとネットワーク',
  '5. 横の繋がり ― 契約・課金',
  '6. ハンズオン',
];

const errors = [];

function walk(dir) {
  const out = [];
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry);
    if (statSync(p).isDirectory()) out.push(...walk(p));
    else if (entry.endsWith('.md')) out.push(p);
  }
  return out;
}

// フェンス内の見出しは拾わない。```mermaid や ```markdown の中の # を誤検出するため。
function headings(text, level) {
  const prefix = '#'.repeat(level) + ' ';
  const out = [];
  let inFence = false;
  for (const line of text.split('\n')) {
    if (/^\s*```/.test(line)) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    if (line.startsWith(prefix)) out.push(line.slice(prefix.length).trim());
  }
  return out;
}

function sectionBody(text, level, title) {
  const lines = text.split('\n');
  const prefix = '#'.repeat(level) + ' ';
  let start = -1;
  let inFence = false;
  for (let i = 0; i < lines.length; i++) {
    if (/^\s*```/.test(lines[i])) inFence = !inFence;
    if (inFence) continue;
    if (start === -1 && lines[i].startsWith(prefix) && lines[i].slice(prefix.length).trim() === title) {
      start = i + 1;
      continue;
    }
    if (start !== -1 && /^#{1,6} /.test(lines[i]) && !lines[i].startsWith('#'.repeat(level + 1))) {
      return lines.slice(start, i).join('\n');
    }
  }
  return start === -1 ? null : lines.slice(start).join('\n');
}


// 本文が参照するリポジトリ内のパスが実在するかを検査する。
// 本文と実ファイルの一致は本書の Operation as Code の前提そのものなので、
// リネームで散文だけが古くなる事故を CI で止める。
// chNN / NN はテンプレート上のプレースホルダなので対象外にする。
const PLACEHOLDER = /(^|\/)(ch)?NN[-.]|\bNN\b/;

function checkPathRefs(rel, text) {
  // Markdown リンク: [表示](manuscript/... )
  for (const m of text.matchAll(/\]\((?!https?:|#|mailto:)([^)\s]+)\)/g)) {
    const target = m[1].split('#')[0];
    if (!target || PLACEHOLDER.test(target)) continue;
    const base = rel === 'README.md' || !rel.includes('/') ? ROOT : join(ROOT, rel, '..');
    if (!existsSync(join(base, target))) {
      errors.push(`${rel}: リンク先が存在しない -> ${target}`);
    }
  }
  // インラインコード中のリポジトリ内パス: `scripts/...` `infra/...`
  for (const m of text.matchAll(/`((?:scripts|infra|manuscript|templates|docs|proposal)\/[^`\s]+)`/g)) {
    const target = m[1];
    if (PLACEHOLDER.test(target) || target.includes('*')) continue;
    if (!existsSync(join(ROOT, target))) {
      errors.push(`${rel}: 参照先が存在しない -> ${target}`);
    }
  }
}

const files = walk(MANUSCRIPT).sort();
if (files.length === 0) errors.push('manuscript/ に原稿が 1 つもない');

for (const file of files) {
  const rel = relative(ROOT, file);
  const text = readFileSync(file, 'utf8');
  checkPathRefs(rel, text);

  // 本文の太字は禁止。どこが重要かは読者が決めるものであり、書き手が強調で固定しない。
  // コードフェンス内は対象外にする。
  {
    let inFence = false;
    const lines = text.split('\n');
    for (let i = 0; i < lines.length; i++) {
      if (/^\s*```/.test(lines[i])) { inFence = !inFence; continue; }
      if (inFence) continue;
      if (/\*\*[^*]+\*\*|__[^_]+__/.test(lines[i])) {
        errors.push(`${rel}:${i + 1}: 本文で太字を使わない`);
      }
    }
  }

  const h1 = headings(text, 1);
  const h2 = headings(text, 2);

  if (h1.length !== 1) {
    errors.push(`${rel}: H1 は 1 つでなければならない (現在 ${h1.length} 個)`);
  }

  // 付録は章の構造規約の対象外
  const isAppendix = rel.includes('/appendix/');

  if (!h2.includes('検証環境')) {
    errors.push(`${rel}: "## 検証環境" ブロックがない`);
  }

  if (!isAppendix) {
    if (h2[h2.length - 1] !== '理解チェック') {
      errors.push(`${rel}: 章末が "## 理解チェック" でない (現在: ${h2[h2.length - 1] ?? 'なし'})`);
    } else {
      const body = sectionBody(text, 2, '理解チェック') ?? '';
      const questions = body.split('\n').filter((l) => /^\d+\.\s+\S/.test(l.trim())).length;
      if (questions !== 3) {
        errors.push(`${rel}: 理解チェックの設問は 3 問でなければならない (現在 ${questions} 問)`);
      }
    }
  }

  if (rel.includes('/part4/')) {
    const found = h2.filter((h) => PART4_BLOCKS.includes(h));
    for (const block of PART4_BLOCKS) {
      if (!h2.includes(block)) errors.push(`${rel}: 6 ブロックの "${block}" がない`);
    }
    const expected = PART4_BLOCKS.filter((b) => h2.includes(b));
    if (JSON.stringify(found) !== JSON.stringify(expected)) {
      errors.push(`${rel}: 6 ブロックの順序が規約と違う`);
    }
  }
}

for (const doc of ['README.md', 'WRITING_GUIDELINES.md']) {
  const p = join(ROOT, doc);
  if (existsSync(p)) checkPathRefs(doc, readFileSync(p, 'utf8'));
}

if (errors.length > 0) {
  console.error('構成規約の違反:');
  for (const e of errors) console.error(`  - ${e}`);
  process.exit(1);
}
console.log(`構成規約 OK (${files.length} ファイル)`);

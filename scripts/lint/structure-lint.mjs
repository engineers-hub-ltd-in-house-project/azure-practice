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

function basenameChapter(rel) {
  const m = rel.match(/\/(\d{2})-[^/]+\.md$/);
  return m ? parseInt(m[1], 10) : null;
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

  // ハンズオンの自己完結性の検査。
  // 1) 章の bash ブロック内で、別の章のリソース名 (azp-chNN-...) を参照しない
  // 2) azp-chNN-rg を使う章は、章内で az group create するか、章スクリプトを参照する
  {
    const m = basenameChapter(rel);
    if (m !== null) {
      const lines2 = text.split('\n');
      let inBash = false;
      const bashText = [];
      for (const line of lines2) {
        if (/^\s*```bash/.test(line)) { inBash = true; continue; }
        if (inBash && /^\s*```/.test(line)) { inBash = false; continue; }
        if (inBash) bashText.push(line);
      }
      const bash = bashText.join('\n');
      for (const ref of bash.matchAll(/azp-ch(\d+)/g)) {
        if (parseInt(ref[1], 10) !== m) {
          errors.push(`${rel}: 第${m}章のコマンドが別の章のリソース azp-ch${ref[1]}... を参照している。章の手順は章内で完結させる`);
          break;
        }
      }
      const rgName = `azp-ch${String(m).padStart(2, '0')}-rg`;
      const usesRg = bash.includes(rgName);
      const createsRg = new RegExp(`az group create[^\n]*${rgName}`).test(bash);
      const usesScript = text.includes(`scripts/chapters/ch${String(m).padStart(2, '0')}`);
      if (usesRg && !createsRg && !usesScript) {
        errors.push(`${rel}: ${rgName} を参照しているが、章内に az group create も章スクリプトへの参照もない`);
      }
    }
  }

  // 手順のコマンドブロック内の行頭コメントは禁止。説明は本文に書く。
  // （コピペの単位を小さく保つ。行末の補足コメントは許可する）
  {
    const lines3 = text.split('\n');
    let inBash = false;
    for (let i = 0; i < lines3.length; i++) {
      if (/^\s*```bash/.test(lines3[i])) { inBash = true; continue; }
      if (inBash && /^\s*```/.test(lines3[i])) { inBash = false; continue; }
      if (inBash && /^\s*#\s/.test(lines3[i])) {
        errors.push(`${rel}:${i + 1}: bash ブロック内の行頭コメント。説明は本文に出す`);
      }
    }
  }

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

  // H1 の書式。角括弧ラベル（[統合ハンズオン] など）が規約のないまま
  // 企画書から転写された実績があるため、型を機械で固定する。
  if (h1.length === 1) {
    const title = h1[0];
    if (isAppendix) {
      if (!/^付録 [A-Z] .+$/.test(title)) {
        errors.push(`${rel}: 付録の H1 は "付録 X タイトル" の形にする (現在: ${title})`);
      }
    } else if (!/^第 \d+ 章 .+$/.test(title)) {
      errors.push(
        `${rel}: 章の H1 は "第 N 章 主題" または "第 N 章 主題 ― サブタイトル" の形にする (現在: ${title})`,
      );
    } else {
      const declared = parseInt(title.match(/^第 (\d+) 章/)[1], 10);
      const fromName = basenameChapter(rel);
      if (fromName !== null && declared !== fromName) {
        errors.push(`${rel}: H1 の章番号 ${declared} がファイル名の ${fromName} と一致しない`);
      }
      if (/\/\d{2}-hands-on-[^/]+\.md$/.test(rel) && !/^第 \d+ 章 ハンズオン ― /.test(title)) {
        errors.push(`${rel}: ハンズオン章の H1 は "第 N 章 ハンズオン ― …" の形にする (現在: ${title})`);
      }
    }
    if (/[[\]]/.test(title)) {
      errors.push(`${rel}: H1 に角括弧を使わない。主題の前にラベルを付けない (現在: ${title})`);
    }
  }

  // 各章に図を最低 1 枚。図解不足は指摘で確認された執筆の癖であり、機械で縛る。
  // 付録は対象外。
  if (!isAppendix) {
    const diagrams = (text.match(/```mermaid/g) || []).length;
    if (diagrams === 0) {
      errors.push(`${rel}: 図が 1 枚もない。主要概念の構造を Mermaid で図解する`);
    }
  }

  if (!h2.includes('検証環境')) {
    errors.push(`${rel}: "## 検証環境" ブロックがない`);
  }

  if (!isAppendix) {
    if (h2[h2.length - 1] !== '理解度チェック') {
      errors.push(`${rel}: 章末が "## 理解度チェック" でない (現在: ${h2[h2.length - 1] ?? 'なし'})`);
    } else {
      const body = sectionBody(text, 2, '理解度チェック') ?? '';
      const questions = body.split('\n').filter((l) => /^\d+\.\s+\S/.test(l.trim())).length;
      if (questions !== 3) {
        errors.push(`${rel}: 理解度チェックの設問は 3 問でなければならない (現在 ${questions} 問)`);
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

// 実在の顧客名・テナント/サブスクリプション識別子・個人ドメインを公開リポジトリに載せない。
// 例示はダミー値を使う。ここに挙げる語は検証環境から漏れやすいものの拒否リスト。
const FORBIDDEN_IDENTIFIERS = [
  /syslea/i, /frictio/i, /medii/i,
  /ba9d0cbe/, /8a7c850a/, /417dfc63/, /fe6c7ed6/,
  /ff467136/, /76d5d76a/, /c5940261/, /yusukesatoengineershub/,
];
for (const file of [...walk(MANUSCRIPT), join(ROOT, 'README.md'), join(ROOT, 'WRITING_GUIDELINES.md')]) {
  if (!existsSync(file)) continue;
  const rel = relative(ROOT, file);
  const body = readFileSync(file, 'utf8');
  for (const pat of FORBIDDEN_IDENTIFIERS) {
    if (pat.test(body)) errors.push(`${rel}: 実在の識別子・顧客名が含まれている -> ${pat}`);
  }
}

for (const doc of ['README.md', 'WRITING_GUIDELINES.md']) {
  const p = join(ROOT, doc);
  if (existsSync(p)) checkPathRefs(doc, readFileSync(p, 'utf8'));
}

// 章の区分は「第N部」で書く。英語の Part も漢数字も混ぜない。
// 読者が本文で辿る単位を 章 と 部 の 2 つに揃えるため。ディレクトリ名は対象外。
for (const file of [
  ...walk(MANUSCRIPT),
  join(ROOT, 'README.md'),
  join(ROOT, 'WRITING_GUIDELINES.md'),
  ...walk(join(ROOT, 'templates')),
]) {
  if (!existsSync(file)) continue;
  const rel = relative(ROOT, file);
  const lines = readFileSync(file, 'utf8').split('\n');
  for (let i = 0; i < lines.length; i++) {
    // パスとして書かれた part1/ などと、規約が反例として引用する語は表記の対象外
    const text = lines[i]
      .replace(/`[^`]*`/g, '')
      .replace(/[\w./-]*part\d[\w./-]*/gi, '');
    if (/Part\s*\d/.test(text)) {
      errors.push(`${rel}:${i + 1}: 章の区分は「第N部」と書く。Part N と英語で書かない`);
    }
    if (/第[一二三四五六七八九十]+部/.test(text)) {
      errors.push(`${rel}:${i + 1}: 部の番号は算用数字で書く（第一部 ではなく 第 1 部）`);
    }
  }
}

// ASCII と日本語の境目には半角スペースを 1 つ置く。第 4 章・付録 B・404 のような
// 数字や英字が地の文に埋もれると読点の位置が読めなくなるため。
// 全角の約物との隣接は詰める。コマンドと実際の出力を貼ったブロックは記録なので触らない。
const JA = 'ぁ-んァ-ヶ一-鿿々ー';
const KEEP_FENCE = new Set(['bash', 'text', 'bicep', 'json', 'sh', 'console', 'yaml', 'markdown']);
for (const file of [
  ...walk(MANUSCRIPT),
  join(ROOT, 'README.md'),
  join(ROOT, 'WRITING_GUIDELINES.md'),
]) {
  if (!existsSync(file)) continue;
  const rel = relative(ROOT, file);
  const lines = readFileSync(file, 'utf8').split('\n');
  let fence = null;
  for (let i = 0; i < lines.length; i++) {
    const open = lines[i].match(/^\s*```(\w*)/);
    if (open) {
      fence = fence === null ? open[1] || 'text' : null;
      continue;
    }
    if (fence !== null && KEEP_FENCE.has(fence)) continue;
    const prose = lines[i]
      .replace(/`[^`]*`/g, '')
      .replace(/\]\([^)]*\)/g, ']')
      .replace(/<[^>]*>/g, '')
      .replace(/https?:\/\/\S+/g, '');
    const m =
      prose.match(new RegExp(`[${JA}][A-Za-z0-9]`)) ?? prose.match(new RegExp(`[A-Za-z0-9][${JA}]`));
    if (m) {
      errors.push(`${rel}:${i + 1}: ASCII と日本語の間に半角スペースを置く -> ${m[0]}`);
    }

    // 日本語どうしの間に半角スペースを挟まない。一括置換の取りこぼしがここに出る
    // （「第 2 部 までのハンズオン」）。見出しの番号とタイトルの区切りは除く。
    const body = prose.replace(/^(#{1,6} )?(第 \d+(?:[〜・]\d+)* [章部]|付録 [A-Z]) /, '');
    const gap = body.replace(/\|/g, '').match(new RegExp(`[${JA}] [${JA}]`));
    if (gap && !prose.includes('|')) {
      errors.push(`${rel}:${i + 1}: 日本語の間に半角スペースが入っている -> ${gap[0]}`);
    }
  }
}

if (errors.length > 0) {
  console.error('構成規約の違反:');
  for (const e of errors) console.error(`  - ${e}`);
  process.exit(1);
}
console.log(`構成規約 OK (${files.length} ファイル)`);

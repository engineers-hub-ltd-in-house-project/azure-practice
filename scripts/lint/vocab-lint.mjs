#!/usr/bin/env node
// 語彙の検査。造語が原稿に入るのを、抽象度の高い側から順に止める。
//
// 見つけた造語を禁止語に足していく運用は、指摘の数だけ増えて終わらない。
// そこで、語を決める行為そのものと、語彙が増えること自体を検査の対象にする。
//
// 検査 1（方針）: docs/vocabulary.json の operations に出典（source）が無い行を落とす。
//                 操作を表す語は、az のコマンドやフラグに実在する語から採る。
// 検査 2（方針）: 比喩の導入句を落とす。本書の造語はここから作られてきた。
// 検査 3（文脈）: 「〜と呼びます」で語を決めたら、その語が用語集にあることを求める。
// 検査 4（語）  : docs/vocabulary.json の denied のうち lint が vocab のものを落とす。
// 検査 5（語）  : 語彙スナップショットに無い語を落とす。残すなら npm run vocab:update。
//
// コードフェンス内は対象外（コマンドと実出力は実物を尊重する）。

import { readFileSync, existsSync } from 'node:fs';
import { join, relative } from 'node:path';
import { proseLines, tokensOf, walkMarkdown } from './lib-vocabulary.mjs';

const ROOT = new URL('../../', import.meta.url).pathname;
const VOCAB = JSON.parse(readFileSync(join(ROOT, 'docs/vocabulary.json'), 'utf8'));
const GLOSSARY = JSON.parse(readFileSync(join(ROOT, 'docs/glossary.json'), 'utf8'));
const SNAPSHOT = join(ROOT, 'docs/vocabulary-snapshot.txt');

const errors = [];
const files = walkMarkdown(join(ROOT, 'manuscript'));

// 検査 1: 出典のない操作語は正典に置けない
for (const op of VOCAB.operations ?? []) {
  if (!op.source || !op.source.trim()) {
    errors.push(
      `docs/vocabulary.json: "${op.object}" の ${op.verb} に出典がない。az のコマンドやフラグ、公式の日本語表記を書く`,
    );
  }
}

const deniedHere = (VOCAB.denied ?? []).filter((d) => d.lint === 'vocab');
const markers = VOCAB.coining?.markers ?? [];
const known = new Set(Object.keys(GLOSSARY.terms ?? {}));

for (const file of files) {
  const rel = relative(ROOT, file);
  const lines = proseLines(readFileSync(file, 'utf8'));
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!line) continue;

    // 検査 2 と 4: 正典の denied（比喩の導入句もここに入っている）
    for (const d of deniedHere) {
      const m = line.match(new RegExp(d.pattern));
      if (m) {
        errors.push(`${rel}:${i + 1}: "${m[0]}" は使わない。${d.instead} と書く（${d.why}）`);
      }
    }

    // 検査 3: 語を決めた宣言は、用語集への登録とセットにする
    for (const marker of markers) {
      if (!line.includes(marker)) continue;
      const before = line.slice(0, line.indexOf(marker));
      const quoted = [...before.matchAll(/[「『]([^」』]+)[」』]/g)].map((q) => q[1]);
      const bare = before.match(/([ァ-ヶー一-龥々A-Za-z][ァ-ヶー一-龥々A-Za-z0-9 ]*)$/);
      const candidates = quoted.length > 0 ? quoted : bare ? [bare[1].trim()] : [];
      for (const term of candidates) {
        if (!term || term.length < 2) continue;
        if (known.has(term)) continue;
        errors.push(
          `${rel}:${i + 1}: 「${term}」を本書の語として決めている。docs/glossary.json の terms へ初出章つきで登録する`,
        );
      }
    }
  }
}

// 検査 5: 新語ゲート。スナップショットに無い語は、言い換えるか、判断して足すかのどちらかにする。
if (existsSync(SNAPSHOT)) {
  const snapshot = new Set(
    readFileSync(SNAPSHOT, 'utf8')
      .split('\n')
      .map((l) => l.trim())
      .filter((l) => l && !l.startsWith('#')),
  );
  const fresh = new Set();
  for (const file of files) {
    for (const t of tokensOf(readFileSync(file, 'utf8'))) {
      if (!snapshot.has(t)) fresh.add(`${relative(ROOT, file)}: ${t}`);
    }
  }
  const list = [...fresh].slice(0, 20);
  for (const s of list) {
    errors.push(`${s} がスナップショットに無い。言い換えを検討し、残すなら npm run vocab:update`);
  }
  if (fresh.size > list.length) errors.push(`（ほかに ${fresh.size - list.length} 件の新語がある）`);
} else {
  errors.push('docs/vocabulary-snapshot.txt が無い。npm run vocab:update で作る');
}

if (errors.length > 0) {
  console.error('語彙の違反:');
  for (const e of [...new Set(errors)].slice(0, 40)) console.error(`  - ${e}`);
  process.exit(1);
}
console.log(`語彙 OK (${files.length} ファイル)`);

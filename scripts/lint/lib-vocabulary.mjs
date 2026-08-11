// 語彙の切り出し。検査（vocab-lint.mjs）と生成（vocabulary-tokens.mjs）で共有する。
// 2 か所で別々に実装すると切り出しがずれ、差分が毎回出て検査が形骸化する。

import { readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

// フェンスの外の本文だけを返す。インラインコードも語彙の対象から外す。
// 行番号を保つため、対象外の行は空文字にして詰めない。
export function proseLines(text) {
  const out = [];
  let fenced = false;
  for (const line of text.split('\n')) {
    if (/^\s*```/.test(line)) {
      fenced = !fenced;
      out.push('');
      continue;
    }
    out.push(fenced ? '' : line.replace(/`[^`]*`/g, ''));
  }
  return out;
}

// 語彙として数えるトークン。カタカナ語、漢字 2 字以上、漢字と送り仮名の複合を拾う。
// 助詞や活用語尾は拾わない。新しい語が入ったことを検出できれば足りる。
export const TOKEN = /[ァ-ヶー]{3,}|[一-龥々]{2,}|[一-龥]{1,2}[ぁ-ん]{1,2}[一-龥]{1,2}/g;

export function tokensOf(text) {
  const out = new Set();
  for (const line of proseLines(text)) {
    for (const m of line.matchAll(TOKEN)) out.add(m[0]);
  }
  return out;
}

export function walkMarkdown(dir) {
  const out = [];
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry);
    if (statSync(p).isDirectory()) out.push(...walkMarkdown(p));
    else if (entry.endsWith('.md')) out.push(p);
  }
  return out.sort();
}

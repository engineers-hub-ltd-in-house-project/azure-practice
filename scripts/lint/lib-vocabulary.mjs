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

// 語彙として数えるトークン。カタカナ語と、漢字 2 字以上の連なりだけを拾う。
// 送り仮名を挟む形（「載せ先」）も拾おうとすると、「秒ほど待」「手が次」のように
// 語をまたいだ断片が大量に出て、書き換えのたびに新語として落ちる。誤検出の多い
// 検出器は無視されるようになるため、ここでは拾わない。送り仮名を含む言い換えは
// docs/vocabulary.json の denied（層 3 の言い換え表）が受け持つ。
export const TOKEN = /[ァ-ヶー]{3,}|[一-龥々]{2,}/g;

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

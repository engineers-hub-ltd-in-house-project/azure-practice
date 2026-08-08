#!/usr/bin/env bash
# 各章の「検証環境」ブロックから docs/verification-log.md を組み立て直す。
# 一覧表を手書きしないための唯一の入口。原稿側が常に一次情報になる。

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$root" <<'PY'
import pathlib, re, sys

root = pathlib.Path(sys.argv[1])
rows = []

for path in sorted((root / 'manuscript').rglob('*.md')):
    text = path.read_text(encoding='utf-8')
    title = next((l[2:].strip() for l in text.splitlines() if l.startswith('# ')), path.stem)
    block = re.search(r"## 検証環境\n\n(\|.*?)(?=\n\n## |\Z)", text, re.S)
    values = {}
    if block:
        for line in block.group(1).splitlines():
            cells = [c.strip() for c in line.strip().strip('|').split('|')]
            if len(cells) == 2 and cells[0] not in ('項目', '---'):
                values[cells[0]] = cells[1]
    rows.append((
        path.relative_to(root).as_posix(),
        title,
        values.get('検証状態', '-'),
        values.get('検証日', '-'),
        values.get('Azure CLI', '-'),
        values.get('Bicep CLI', '-'),
        values.get('API バージョン', '-'),
    ))

counts = {}
for r in rows:
    counts[r[2]] = counts.get(r[2], 0) + 1
summary = ' / '.join(f'{k}: {v}' for k, v in sorted(counts.items()))

out = [
    '# 検証ログ',
    '',
    'このファイルは `scripts/render-verification-log.sh` が生成する。手で編集しない。',
    '各章の「検証環境」ブロックが一次情報であり、ここはその集約にすぎない。',
    '',
    '| 状態 | 意味 |',
    '| --- | --- |',
    '| verified | 実機で手順を通し、期待どおりの結果を確認した |',
    '| pending | 未検証。本文の手順は公式ドキュメントに基づくが実行していない |',
    '| blocked | 権限やクォータの都合で検証できなかった。理由を章内に記す |',
    '',
    f'集計: {summary}',
    '',
    '| 章 | 状態 | 検証日 | Azure CLI | Bicep CLI | API バージョン |',
    '| --- | --- | --- | --- | --- | --- |',
]
for rel, title, state, day, azv, bicepv, api in rows:
    out.append(f'| [{title}]({"../" + rel}) | {state} | {day} | {azv} | {bicepv} | {api} |')
out.append('')

(root / 'docs' / 'verification-log.md').write_text('\n'.join(out), encoding='utf-8')
print(f'docs/verification-log.md を更新した ({len(rows)} 章)')
PY

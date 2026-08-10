#!/usr/bin/env bash
# 検出器そのものを検査する。原稿に違反を注入して、対応する lint が落ちることを確かめる。
#
# 動かない検出器は、無い検出器より悪い。CI が緑であることが「規約が守られている」
# ではなく「検査していない」を意味するようになるためである。規則の書き換えや
# 正規表現の修正で検出器が黙ることは実際に起きるので、機械で見張る。
#
# リポジトリを一時ディレクトリへ複製したうえで壊すため、作業ツリーには影響しない。

set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

tar -C "$root" --exclude=.git --exclude=node_modules -cf - . | tar -C "$work" -xf -

pass=0
dead=0

# $1 説明 / $2 対象ファイル / $3 python の書き換え式 / $4 落ちるべき lint
probe() {
  local desc="$1" file="$2" mutation="$3" linter="$4"
  cp "$work/$file" "$work/.orig"
  python3 - "$work/$file" "$mutation" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
t = p.read_text(encoding='utf-8')
exec(sys.argv[2])
p.write_text(t, encoding='utf-8')
PY
  if diff -q "$work/.orig" "$work/$file" >/dev/null 2>&1; then
    echo "  注入できず  $desc（原稿の変化に追随していない。この検査を直すこと）"
    dead=$((dead + 1))
  elif (cd "$work" && node "scripts/lint/$linter" >/dev/null 2>&1); then
    echo "  発火しない  $desc"
    dead=$((dead + 1))
  else
    echo "  OK          $desc"
    pass=$((pass + 1))
  fi
  cp "$work/.orig" "$work/$file"
}

CH=manuscript/part1/03-resource-groups.md
P4=manuscript/part4/14-functions.md

echo "== structure-lint =="
probe "太字の禁止" "$CH" "t = t.replace('リソースグループは、Azure で', '**リソースグループ**は、Azure で')" structure-lint.mjs
probe "H1 は 1 つ" "$CH" "t = t + chr(10) + '# 余計な H1'" structure-lint.mjs
probe "H1 の書式" "$CH" "t = t.replace('# 第 3 章 リソースグループ', '# リソースグループ')" structure-lint.mjs
probe "H1 の章番号とファイル名の一致" "$CH" "t = t.replace('# 第 3 章', '# 第 7 章')" structure-lint.mjs
probe "H1 の角括弧の禁止" "$CH" "t = t.replace('# 第 3 章 ', '# 第 3 章 [まとめ] ')" structure-lint.mjs
probe "章に図が 1 枚以上" "$CH" "t = t.replace('\`\`\`mermaid', '\`\`\`text')" structure-lint.mjs
probe "検証環境ブロック" "$CH" "t = t.replace('## 検証環境', '## かんきょう')" structure-lint.mjs
probe "章末が理解度チェック" "$CH" "t = t + chr(10) + '## あとがき' + chr(10)" structure-lint.mjs
probe "設問は 3 問" "$CH" "t = t.rstrip() + chr(10) + '4. 4 問目' + chr(10)" structure-lint.mjs
probe "実在の識別子の拒否" "$CH" "t = t.replace('japaneast', 'medii', 1)" structure-lint.mjs
probe "リンク先の実在" "$CH" "t = t.replace('## 検証環境', '[壊れた](../nowhere.md)' + chr(10) + chr(10) + '## 検証環境')" structure-lint.mjs
probe "Part N の英語表記の禁止" "$CH" "t = t.replace('第 1 章で', 'Part 1 で')" structure-lint.mjs
probe "部の番号は算用数字" "$CH" "t = t.replace('第 1 章で', '第一部で')" structure-lint.mjs
probe "ASCII と日本語の間隔" "$CH" "t = t.replace('第 0 章の', '第0章の', 1)" structure-lint.mjs
probe "日本語の間の余分な空白" "$CH" "t = t.replace('置く単位です。', '置く 単位です。')" structure-lint.mjs
probe "bash の行頭コメントの禁止" "$CH" "t = t.replace('az group show', '# 説明' + chr(10) + 'az group show')" structure-lint.mjs
probe "1 ステップ 1 ブロック" "$CH" "t = t.replace('az group show --name <名前>', 'az group list' + chr(10) + 'az group show --name <名前>')" structure-lint.mjs
probe "未代入の変数の禁止" "$CH" "t = t.replace('az group show --name <名前>', 'az group show --name \"\$undefined_var\"')" structure-lint.mjs
probe "理解の指示は肯定形" "$CH" "t = t.replace('必須であるがゆえに', '別物だと思わないでください。必須であるがゆえに')" structure-lint.mjs
probe "ですます調" "$CH" "t = t.replace('必須であるがゆえに', 'これは必須である。必須であるがゆえに')" structure-lint.mjs
probe "業界口語を使わない" "$CH" "t = t.replace('必須であるがゆえに', '名前で引くと分かります。必須であるがゆえに')" structure-lint.mjs
probe "業界口語（掛ける）" "$CH" "t = t.replace('必須であるがゆえに', 'スコープに掛けます。必須であるがゆえに')" structure-lint.mjs
probe "擬人化（生まれる）" "$CH" "t = t.replace('必須であるがゆえに', 'ここで実体が生まれます。必須であるがゆえに')" structure-lint.mjs
probe "章に実出力が 1 つ以上" "$CH" "t = t.replace('\`\`\`text', '\`\`\`yaml')" structure-lint.mjs
probe "別章リソースの参照の禁止" "$CH" "t = t.replace('azp-ch03-rg', 'azp-ch09-rg')" structure-lint.mjs
probe "Part 4 の 6 ブロック" "$P4" "t = t.replace('## 2. 縦の依存関係', '## 2. たてのはなし')" structure-lint.mjs

echo "== mermaid-lint =="
probe "図種の宣言" "$CH" "t = t.replace('flowchart TB' + chr(10) + '  subgraph L', '  subgraph L', 1)" mermaid-lint.mjs
probe "括弧を含むラベルの引用" "$CH" "t = t.replace('VM[\"仮想マシン (westus を選択)\"]', 'VM[仮想マシン (westus を選択)]')" mermaid-lint.mjs
probe "ノード種類の後置" "$CH" "t = t.replace('S[\"サブスクリプション\"]', 'S[\"サブスクリプション: 例\"]')" mermaid-lint.mjs

echo "== terms-lint =="
probe "初出章より前で使わない" "$CH" "t = t.replace('置く単位です。', '置く単位です。Workload ID の話です。')" terms-lint.mjs
probe "禁止語" "$CH" "t = t.replace('置く単位です。', '置く単位です。これは布石です。')" terms-lint.mjs
probe "禁止語（比喩の造語）" "$CH" "t = t.replace('置く単位です。', '置く単位です。台帳へ投影されます。')" terms-lint.mjs
probe "禁止語（擬人化）" "$CH" "t = t.replace('置く単位です。', '置く単位です。宿主と一心同体です。')" terms-lint.mjs
probe "未定義の略語" "$CH" "t = t.replace('置く単位です。', '置く単位です。ZZQ を使います。')" terms-lint.mjs
probe "図の初見の固有名" "$CH" "t = t.replace('ST[\"ストレージ (japaneast を選択)\"]', 'ST[\"Cosmos Table Storage\"]')" terms-lint.mjs
probe "設問の語が本文にある" "$CH" "t = t.rstrip()[:-1] + chr(10) + '4. Workload ID について述べてください' + chr(10)" terms-lint.mjs

echo
if [ "$dead" -gt 0 ]; then
  echo "検出器の自己検査に失敗: 発火 ${pass} / 沈黙 ${dead}"
  exit 1
fi
echo "検出器の自己検査 OK (${pass} 件すべて発火)"

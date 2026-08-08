#!/usr/bin/env bash
# 章の検証結果を docs/verification-log.md と当該章の「検証環境」ブロックに書き込む。
# 検証環境ブロックを手書きしないための唯一の入口。
#
# 使い方: ./scripts/record-verification.sh <章番号> <状態> [APIバージョン]
#   状態: verified | pending | blocked
#
# 例: ./scripts/record-verification.sh 04 verified 'Microsoft.Resources/resourceGroups@2025-04-01'

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

chapter="${1:?章番号を渡す (例: 04)}"
state="${2:?状態を渡す (verified|pending|blocked)}"
api_version="${3:--}"

case "$state" in
  verified|pending|blocked) ;;
  *) die "状態は verified / pending / blocked のいずれか" ;;
esac

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
file=$(find "$root/manuscript" -name "${chapter}-*.md" | head -1)
[[ -n "$file" ]] || die "第${chapter}章の原稿が見つからない"

az_ver=$(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo "-")
bicep_ver=$(az bicep version 2>/dev/null | sed -n 's/.*version \([0-9.]*\).*/\1/p')
: "${bicep_ver:=-}"
today=$(date +%Y-%m-%d)

python3 - "$file" "$state" "$today" "$az_ver" "$bicep_ver" "$api_version" <<'PY'
import re, sys
path, state, day, azv, bicepv, api = sys.argv[1:7]
text = open(path, encoding='utf-8').read()
block = (
    "## 検証環境\n\n"
    "| 項目 | 値 |\n| --- | --- |\n"
    f"| 検証状態 | {state} |\n"
    f"| 検証日 | {day} |\n"
    f"| Azure CLI | {azv} |\n"
    f"| Bicep CLI | {bicepv} |\n"
    f"| API バージョン | {api} |\n"
)
new, n = re.subn(r"## 検証環境\n\n\|.*?\n(?=\n## |\Z)", block, text, count=1, flags=re.S)
if n == 0:
    raise SystemExit(f"{path}: 検証環境ブロックが見つからない")
open(path, 'w', encoding='utf-8').write(new)
PY

log "第${chapter}章の検証環境ブロックを更新した: ${state}"

# 一覧表は原稿側を一次情報として作り直す
"$root/scripts/render-verification-log.sh"

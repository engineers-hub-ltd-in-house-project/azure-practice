#!/usr/bin/env bash
# 第9章のクリーンアップ。
# ロール割り当てはすべて RG 配下のスコープに掛けたので、RG の削除で一緒に消える。
# ID より先に割り当てが消える順序になっていることも、この設計の利点である（第6章）。

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

prefix="${AZP_PREFIX}"
chapter="ch09"
rg="${prefix}-${chapter}-rg"

require_cmd az
confirm_subscription

log "リソースグループ ${rg} を削除する"
az group delete --name "$rg" --yes 2>/dev/null || warn "リソースグループが存在しない"
log "クリーンアップ完了"

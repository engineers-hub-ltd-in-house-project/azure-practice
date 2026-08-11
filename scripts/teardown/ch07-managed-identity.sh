#!/usr/bin/env bash
# 第 7 章のクリーンアップ。
# ロール割り当てはすべて RG 配下のスコープに割り当てたので、RG の削除で一緒に消える。
# システム割り当ての ID は、載せ先のコンテナーが消えた時点でテナントの台帳からも消える。

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

prefix="${AZP_PREFIX}"
chapter="ch07"
rg="${prefix}-${chapter}-rg"

require_cmd az
confirm_subscription

log "リソースグループ ${rg} を削除する"
az group delete --name "$rg" --yes 2>/dev/null || warn "リソースグループが存在しない"
log "クリーンアップ完了"

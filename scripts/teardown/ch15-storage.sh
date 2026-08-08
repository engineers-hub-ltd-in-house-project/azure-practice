#!/usr/bin/env bash
# 第15章のクリーンアップ。

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_cmd az
confirm_subscription

log "リソースグループ azp-ch15-rg を削除する"
az group delete --name azp-ch15-rg --yes 2>/dev/null || warn "リソースグループが存在しない"
log "クリーンアップ完了"

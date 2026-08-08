#!/usr/bin/env bash
# 第14章のクリーンアップ。Function App・暗黙に作られたプラン・Application Insights・
# ストレージがまとめて消える。

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_cmd az
confirm_subscription

log "リソースグループ azp-ch14-rg を削除する"
az group delete --name azp-ch14-rg --yes 2>/dev/null || warn "リソースグループが存在しない"
log "クリーンアップ完了"

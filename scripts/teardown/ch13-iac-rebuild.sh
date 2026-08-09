#!/usr/bin/env bash
# 第 13 章のクリーンアップ。スタックの削除 1 操作で、リソースグループごと消える。
# actionOnUnmanage を deleteAll にしてあるため、管理下のリソースが道連れになる。

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_cmd az
confirm_subscription

log "スタック azp-ch13-stack を削除する（管理下のリソースごと）"
az stack sub delete --name azp-ch13-stack --action-on-unmanage deleteAll --yes 2>/dev/null \
  || warn "スタックが存在しない"
log "クリーンアップ完了"

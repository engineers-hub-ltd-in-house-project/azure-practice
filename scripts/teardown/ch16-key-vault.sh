#!/usr/bin/env bash
# 第16章のクリーンアップ。Key Vault は論理削除されるため、purge まで行わないと
# 名前が 90 日間予約されたままになり、章を再実行できなくなる（第3章）。

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

location="${AZP_LOCATION}"

require_cmd az
confirm_subscription

sub_id=$(az account show --query id -o tsv)
suffix=$(echo "$sub_id" | tr -d - | cut -c1-8)

log "リソースグループ azp-ch16-rg を削除する"
az group delete --name azp-ch16-rg --yes 2>/dev/null || warn "リソースグループが存在しない"

for kv in "azpch16r${suffix}" "azpch16l${suffix}"; do
  log "論理削除された ${kv} を purge する"
  az keyvault purge --name "$kv" --location "$location" 2>/dev/null || warn "${kv} は論理削除状態にない"
done
log "クリーンアップ完了"

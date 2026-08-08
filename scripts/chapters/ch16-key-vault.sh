#!/usr/bin/env bash
# 第16章 Key Vault ― RBAC 既定化とアクセスポリシーの歴史
# 新旧 2 つの認可モデルの Vault を並べて作り、挙動の差を観察する。

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

location="${AZP_LOCATION}"
rg="azp-ch16-rg"

require_cmd az
confirm_subscription

sub_id=$(az account show --query id -o tsv)
suffix=$(echo "$sub_id" | tr -d - | cut -c1-8)
kv_rbac="azpch16r${suffix}"
kv_legacy="azpch16l${suffix}"

log "リソースグループを作る"
az group create --name "$rg" --location "$location" \
  --tags azp-book=azure-practice azp-chapter=ch16 azp-lifecycle=ephemeral -o none

log "Vault その 1: 何も指定せずに作る（既定の認可モデルを観察する）"
az keyvault create --name "$kv_rbac" -g "$rg" --location "$location" -o none

log "Vault その 2: 旧モデル（アクセスポリシー）を明示して作る"
az keyvault create --name "$kv_legacy" -g "$rg" --location "$location" \
  --enable-rbac-authorization false -o none

log "RBAC Vault にデータロールを割り当てる（これがないと 403 になる）"
me=$(az ad signed-in-user show --query id -o tsv)
assign() {
  az role assignment create --assignee "$me" --role "Key Vault Secrets Officer" \
    --scope "/subscriptions/${sub_id}/resourceGroups/${rg}/providers/Microsoft.KeyVault/vaults/${kv_rbac}" -o none 2>/dev/null
}
retry 3 20 assign

log "完了した。scripts/verify/ch16-key-vault.sh で状態を確認する"

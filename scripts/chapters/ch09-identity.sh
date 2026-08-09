#!/usr/bin/env bash
# 第 9 章 ハンズオン ― ID と権限を 1 つのシナリオで通す
#
# シナリオ: アプリ用の ID と保管場所を、キーを一度も有効にせずに用意する。
# 第 2 部で分解した概念（ID の 2 世界・ロール × スコープ・マネージド ID・
# キーなし認証）を 1 本のシナリオに戻す。

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

prefix="${AZP_PREFIX}"
location="${AZP_LOCATION}"
chapter="ch09"
rg="${prefix}-${chapter}-rg"

require_cmd az
confirm_subscription

sub_id=$(az account show --query id -o tsv)

# --- 1. 器を用意する ---
log "リソースグループ ${rg} を作る"
az group create --name "$rg" --location "$location" \
  --tags azp-book=azure-practice azp-chapter="$chapter" azp-lifecycle=ephemeral -o none

# --- 2. ID を先に作る（第 7 章: ユーザー割り当ては宿主より先に用意できる） ---
log "ユーザー割り当てマネージド ID を作る"
az identity create --name "${prefix}-${chapter}-id" --resource-group "$rg" -o none
principal_id=$(az identity show --name "${prefix}-${chapter}-id" --resource-group "$rg" \
  --query principalId -o tsv)
log "principalId: ${principal_id}"

# --- 3. 保管場所を、生まれた時からキー無効で作る（第 8 章） ---
sa="${prefix}${chapter}$(echo "$sub_id" | tr -d - | cut -c1-8)"
log "ストレージアカウント ${sa} を作る（キー認証は最初から無効）"
az storage account create --name "$sa" --resource-group "$rg" --location "$location" \
  --sku Standard_LRS --allow-shared-key-access false \
  --min-tls-version TLS1_2 --allow-blob-public-access false -o none

# --- 4. 権限を配る（第 6 章: ロール × スコープ） ---
# アプリの ID には RG スコープで。この RG のストレージ全体を扱うアプリという想定。
# スコープを RG にするか各アカウントにするかの判断は本文で議論する。
log "マネージド ID に Storage Blob Data Contributor を RG スコープで割り当てる"
assign_mi() {
  az role assignment create --assignee "$principal_id" \
    --role "Storage Blob Data Contributor" \
    --scope "/subscriptions/${sub_id}/resourceGroups/${rg}" -o none 2>/dev/null
}
retry 3 20 assign_mi

# 運用者（自分）にはアカウント単体のスコープで。必要最小の範囲に絞る。
log "自分に Storage Blob Data Contributor をアカウントスコープで割り当てる"
me=$(az ad signed-in-user show --query id -o tsv)
assign_me() {
  az role assignment create --assignee "$me" \
    --role "Storage Blob Data Contributor" \
    --scope "/subscriptions/${sub_id}/resourceGroups/${rg}/providers/Microsoft.Storage/storageAccounts/${sa}" -o none 2>/dev/null
}
retry 3 20 assign_me

log "完了した。scripts/verify/ch09-identity.sh で状態を確認する"

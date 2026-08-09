#!/usr/bin/env bash
# 第 15 章 Storage ― Functions の隠れた依存関係から理解する
# Function App を作り、その相棒ストレージを完全キーレス化するまで。

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

location="${AZP_LOCATION}"
rg="azp-ch15-rg"

require_cmd az
confirm_subscription

sub_id=$(az account show --query id -o tsv)
sa="azpch15$(echo "$sub_id" | tr -d - | cut -c1-8)"

log "リソースグループとストレージ、Function App を作る"
az group create --name "$rg" --location "$location" \
  --tags azp-book=azure-practice azp-chapter=ch15 azp-lifecycle=ephemeral -o none
az storage account create --name "$sa" -g "$rg" --location "$location" \
  --sku Standard_LRS --allow-blob-public-access false -o none
az functionapp create --name azp-ch15-func -g "$rg" \
  --storage-account "$sa" --flexconsumption-location "$location" \
  --runtime node --runtime-version 20 -o none

log "ホストストレージをマネージド ID 接続へ切り替える"
pid=$(az functionapp identity assign --name azp-ch15-func -g "$rg" --query principalId -o tsv)
scope="/subscriptions/${sub_id}/resourceGroups/${rg}/providers/Microsoft.Storage/storageAccounts/${sa}"
for role in "Storage Blob Data Owner" "Storage Queue Data Contributor" "Storage Table Data Contributor"; do
  assign() { az role assignment create --assignee "$pid" --role "$role" --scope "$scope" -o none 2>/dev/null; }
  retry 3 15 assign
done
az functionapp config appsettings set --name azp-ch15-func -g "$rg" \
  --settings AzureWebJobsStorage__accountName="$sa" -o none
az functionapp config appsettings delete --name azp-ch15-func -g "$rg" \
  --setting-names AzureWebJobsStorage -o none

log "デプロイ側の認証もシステム割り当て ID へ切り替える"
az functionapp deployment config set --name azp-ch15-func -g "$rg" \
  --deployment-storage-auth-type SystemAssignedIdentity -o none
az functionapp config appsettings delete --name azp-ch15-func -g "$rg" \
  --setting-names DEPLOYMENT_STORAGE_CONNECTION_STRING -o none 2>/dev/null || true

log "ストレージのキー認証を止める（完全キーレス化）"
az storage account update --name "$sa" -g "$rg" --allow-shared-key-access false -o none

log "完了した。scripts/verify/ch15-storage.sh で状態を確認する"

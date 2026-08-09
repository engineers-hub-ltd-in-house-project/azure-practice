#!/usr/bin/env bash
# 第 14 章 Functions ― Flex Consumption を軸に課金とネットワークの関係を辿る

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

location="${AZP_LOCATION}"
rg="azp-ch14-rg"

require_cmd az
confirm_subscription

sub_id=$(az account show --query id -o tsv)
sa="azpch14$(echo "$sub_id" | tr -d - | cut -c1-8)"

log "対応リージョンを確認する（Flex Consumption はリージョン一覧を持つ）"
az functionapp list-flexconsumption-locations --query "length(@)" -o tsv

log "リソースグループとストレージを作る"
az group create --name "$rg" --location "$location" \
  --tags azp-book=azure-practice azp-chapter=ch14 azp-lifecycle=ephemeral -o none
az storage account create --name "$sa" -g "$rg" --location "$location" \
  --sku Standard_LRS --allow-blob-public-access false -o none

log "Flex Consumption の Function App を作る"
# Functions は Storage を必須の相棒として要求する（第 15 章の主題）。
# 未登録のプロバイダー (OperationalInsights / insights) があれば CLI が自動登録する。
az functionapp create --name azp-ch14-func -g "$rg" \
  --storage-account "$sa" \
  --flexconsumption-location "$location" \
  --runtime node --runtime-version 20 -o none

log "完了した。scripts/verify/ch14-functions.sh で状態を確認する"

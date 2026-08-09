#!/usr/bin/env bash
# 第13章 ハンズオン ― 第1〜2部の構成を IaC で再現する

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
location="${AZP_LOCATION}"

require_cmd az
confirm_subscription

sub_id=$(az account show --query id -o tsv)
sa="azpch13$(echo "$sub_id" | tr -d - | cut -c1-8)"

log "スタック azp-ch13-stack を作成する（構成の宣言 = 実世界、を宣言する）"
az stack sub create --name azp-ch13-stack --location "$location" \
  --template-file "$root/infra/bicep/chapters/ch13-iac-rebuild/main.bicep" \
  --parameters storageName="$sa" includeStorage=true \
  --action-on-unmanage deleteAll --deny-settings-mode none --yes -o none

log "完了した。scripts/verify/ch13-iac-rebuild.sh で状態を確認する"

#!/usr/bin/env bash
# 第 15 章の期待状態を read-only で検証する。冪等。

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_cmd az
rg="azp-ch15-rg"
sub_id=$(az account show --query id -o tsv)
sa="azpch15$(echo "$sub_id" | tr -d - | cut -c1-8)"
failed=0

log "第15章の状態を検証する"

count=$(az storage container list --account-name "$sa" --auth-mode login \
  --query "length([?starts_with(name, 'app-package')])" -o tsv 2>/dev/null || echo 0)
if [[ "$count" != "0" ]]; then
  printf '  OK   デプロイパッケージのコンテナーが存在する（隠れた依存の実体）\n'
else
  printf '  NG   app-package コンテナーが見つからない\n'
  failed=1
fi

auth=$(az functionapp deployment config show --name azp-ch15-func -g "$rg" \
  --query "storage.authentication.type" -o tsv 2>/dev/null || echo missing)
if [[ "$auth" == "SystemAssignedIdentity" ]]; then
  printf '  OK   デプロイの認証がシステム割り当て ID である\n'
else
  printf '  NG   デプロイの認証が %s である\n' "$auth"
  failed=1
fi

if az functionapp config appsettings list --name azp-ch15-func -g "$rg" \
  --query "[].name" -o tsv 2>/dev/null | grep -qx 'AzureWebJobsStorage'; then
  printf '  NG   接続文字列 AzureWebJobsStorage が残っている\n'
  failed=1
else
  printf '  OK   接続文字列 AzureWebJobsStorage は存在しない\n'
fi

shared=$(az storage account show --name "$sa" -g "$rg" --query allowSharedKeyAccess -o tsv 2>/dev/null || echo missing)
if [[ "$shared" == "false" ]]; then
  printf '  OK   ストレージのキー認証が無効である\n'
else
  printf '  NG   ストレージの状態が %s である\n' "$shared"
  failed=1
fi

if (( failed == 0 )); then
  log "検証に成功した"
else
  die "検証に失敗した項目がある"
fi

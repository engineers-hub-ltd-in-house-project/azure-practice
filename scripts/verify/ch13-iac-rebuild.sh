#!/usr/bin/env bash
# 第 13 章の期待状態を read-only で検証する。冪等。

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_cmd az
sub_id=$(az account show --query id -o tsv)
sa="azpch13$(echo "$sub_id" | tr -d - | cut -c1-8)"
rg="azp-ch13-rg"
failed=0

log "第13章の状態を検証する"

state=$(az stack sub show --name azp-ch13-stack --query provisioningState -o tsv 2>/dev/null || echo missing)
if [[ "$state" == "succeeded" ]]; then
  printf '  OK   スタックが存在し succeeded である\n'
else
  printf '  NG   スタックの状態が %s である\n' "$state"
  failed=1
fi

if az group show --name "$rg" -o none 2>/dev/null; then
  printf '  OK   リソースグループ %s が存在する\n' "$rg"
else
  printf '  NG   リソースグループが存在しない\n'
  failed=1
fi

shared=$(az storage account show --name "$sa" -g "$rg" --query allowSharedKeyAccess -o tsv 2>/dev/null || echo missing)
if [[ "$shared" == "false" ]]; then
  printf '  OK   ストレージのキー認証が無効である\n'
else
  printf '  NG   ストレージの状態が %s である\n' "$shared"
  failed=1
fi

principal_id=$(az identity show --name azp-ch13-id -g "$rg" --query principalId -o tsv 2>/dev/null || echo "")
if [[ -n "$principal_id" ]]; then
  has_role() {
    az role assignment list --assignee "$principal_id" --all \
      --query "[?roleDefinitionName=='Storage Blob Data Contributor'] | length(@)" -o tsv 2>/dev/null \
      | grep -qv '^0$'
  }
  if retry 6 10 has_role; then
    printf '  OK   マネージド ID にデータロールが割り当てられている\n'
  else
    printf '  NG   ロール割り当てを確認できない\n'
    failed=1
  fi
else
  printf '  NG   マネージド ID が存在しない\n'
  failed=1
fi

if (( failed == 0 )); then
  log "検証に成功した"
else
  die "検証に失敗した項目がある"
fi

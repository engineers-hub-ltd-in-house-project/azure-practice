#!/usr/bin/env bash
# 第 4 章の期待状態を read-only で検証する。冪等。
# RBAC の割り当ては即座には伝播しないため、該当箇所はリトライする。

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

prefix="${AZP_PREFIX}"
chapter="ch04"
rg="${prefix}-${chapter}-rg"
mg="${prefix}-${chapter}-mg"

require_cmd az
failed=0

check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '  OK   %s\n' "$label"
  else
    printf '  NG   %s\n' "$label"
    failed=1
  fi
}

log "第4章の状態を検証する"

if az account management-group show --name "$mg" -o none 2>/dev/null; then
  printf '  OK   管理グループ %s が存在する\n' "$mg"
else
  warn "管理グループ ${mg} を確認できない。権限不足でスキップした可能性がある"
fi

check "リソースグループ ${rg} が存在する" az group show --name "$rg"

storage=$(az storage account list --resource-group "$rg" --query "[0].name" -o tsv 2>/dev/null || echo "")
if [[ -n "$storage" ]]; then
  printf '  OK   ストレージアカウント %s が存在する\n' "$storage"
  shared_key=$(az storage account show --name "$storage" --resource-group "$rg" \
    --query allowSharedKeyAccess -o tsv)
  if [[ "$shared_key" == "false" ]]; then
    printf '  OK   キー認証が無効になっている\n'
  else
    printf '  NG   キー認証が有効のままである (allowSharedKeyAccess=%s)\n' "$shared_key"
    failed=1
  fi
else
  printf '  NG   ストレージアカウントが存在しない\n'
  failed=1
fi

identity_id=$(az identity show --name "${prefix}-${chapter}-id" --resource-group "$rg" \
  --query principalId -o tsv 2>/dev/null || echo "")
if [[ -n "$identity_id" ]]; then
  printf '  OK   ユーザー割り当てマネージド ID が存在する\n'
  # ロール割り当ての伝播を待つ
  has_role() {
    az role assignment list --assignee "$identity_id" --all \
      --query "[?roleDefinitionName=='Storage Blob Data Contributor'] | length(@)" -o tsv \
      | grep -qv '^0$'
  }
  if retry 6 10 has_role; then
    printf '  OK   Storage Blob Data Contributor が割り当てられている\n'
  else
    printf '  NG   ロール割り当てを確認できない\n'
    failed=1
  fi
else
  printf '  NG   ユーザー割り当てマネージド ID が存在しない\n'
  failed=1
fi

if (( failed == 0 )); then
  log "検証に成功した"
else
  die "検証に失敗した項目がある"
fi

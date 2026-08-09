#!/usr/bin/env bash
# 第 9 章の期待状態を検証する。データプレーンの疎通確認を含むため、
# 一時ファイルの書き込みを行う（リソースの作成・削除はしない）。

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

prefix="${AZP_PREFIX}"
chapter="ch09"
rg="${prefix}-${chapter}-rg"

require_cmd az
sub_id=$(az account show --query id -o tsv)
sa="${prefix}${chapter}$(echo "$sub_id" | tr -d - | cut -c1-8)"
failed=0

log "第9章の状態を検証する"

shared=$(az storage account show --name "$sa" --resource-group "$rg" \
  --query allowSharedKeyAccess -o tsv 2>/dev/null || echo missing)
if [[ "$shared" == "false" ]]; then
  printf '  OK   キー認証が無効である\n'
else
  printf '  NG   キー認証の状態が %s である\n' "$shared"
  failed=1
fi

if az storage container create --name probe --account-name "$sa" --auth-mode key -o none 2>/dev/null; then
  printf '  NG   キー経路が通ってしまった\n'
  failed=1
else
  printf '  OK   キー経路は拒否される\n'
fi

tmp_file=$(mktemp)
echo "azp-ch09" > "$tmp_file"
upload() {
  az storage container create --name verify --account-name "$sa" --auth-mode login -o none 2>/dev/null &&
  az storage blob upload --container-name verify --account-name "$sa" --auth-mode login \
    --name probe.txt --file "$tmp_file" --overwrite -o none 2>/dev/null
}
if retry 6 20 upload; then
  printf '  OK   Entra ID 認証でデータを書き込めた\n'
else
  printf '  NG   Entra ID 認証の書き込みに失敗した\n'
  failed=1
fi
rm -f "$tmp_file"

principal_id=$(az identity show --name "${prefix}-${chapter}-id" --resource-group "$rg" \
  --query principalId -o tsv 2>/dev/null || echo "")
if [[ -n "$principal_id" ]]; then
  has_role() {
    az role assignment list --assignee "$principal_id" --all \
      --query "[?roleDefinitionName=='Storage Blob Data Contributor'] | length(@)" -o tsv 2>/dev/null \
      | grep -qv '^0$'
  }
  if retry 6 10 has_role; then
    printf '  OK   マネージド ID にデータロールが割り当てられている\n'
  else
    printf '  NG   マネージド ID のロール割り当てを確認できない\n'
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

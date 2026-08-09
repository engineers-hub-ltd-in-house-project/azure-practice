#!/usr/bin/env bash
# 第 16 章の期待状態を検証する。シークレットの書き込みを行う（読み書きのみ）。

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_cmd az
sub_id=$(az account show --query id -o tsv)
suffix=$(echo "$sub_id" | tr -d - | cut -c1-8)
kv_rbac="azpch16r${suffix}"
kv_legacy="azpch16l${suffix}"
failed=0

log "第16章の状態を検証する"

rbac=$(az keyvault show --name "$kv_rbac" --query properties.enableRbacAuthorization -o tsv 2>/dev/null || echo missing)
if [[ "$rbac" == "true" ]]; then
  printf '  OK   無指定で作った Vault の認可モデルが RBAC である\n'
else
  printf '  NG   無指定 Vault の enableRbacAuthorization が %s である\n' "$rbac"
  failed=1
fi

legacy=$(az keyvault show --name "$kv_legacy" --query properties.enableRbacAuthorization -o tsv 2>/dev/null || echo missing)
policies=$(az keyvault show --name "$kv_legacy" --query "length(properties.accessPolicies)" -o tsv 2>/dev/null || echo 0)
if [[ "$legacy" == "false" && "$policies" == "1" ]]; then
  printf '  OK   旧モデル Vault に作成者のアクセスポリシーが自動で入っている\n'
else
  printf '  NG   旧モデル Vault の状態が rbac=%s policies=%s である\n' "$legacy" "$policies"
  failed=1
fi

write_rbac() {
  az keyvault secret set --vault-name "$kv_rbac" --name verify --value ok -o none 2>/dev/null
}
if retry 6 20 write_rbac; then
  printf '  OK   RBAC Vault にロール経由で書き込めた\n'
else
  printf '  NG   RBAC Vault への書き込みに失敗した\n'
  failed=1
fi

if az keyvault secret set --vault-name "$kv_legacy" --name verify --value ok -o none 2>/dev/null; then
  printf '  OK   旧モデル Vault にポリシー経由で書き込めた\n'
else
  printf '  NG   旧モデル Vault への書き込みに失敗した\n'
  failed=1
fi

if (( failed == 0 )); then
  log "検証に成功した"
else
  die "検証に失敗した項目がある"
fi

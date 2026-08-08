#!/usr/bin/env bash
# ハンズオンの前提が揃っているかを確認する。リソースは作らない。
# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_cmd az jq

log "Azure CLI: $(az version --query '\"azure-cli\"' -o tsv)"
log "Bicep CLI: $(az bicep version 2>/dev/null | sed -n 's/.*version \([0-9.]*\).*/\1/p')"

confirm_subscription

sub_id=$(az account show --query id -o tsv)
principal_id=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || echo "")

log "サブスクリプションスコープのロール割り当て:"
if [[ -n "$principal_id" ]]; then
  az role assignment list --assignee "$principal_id" --scope "/subscriptions/${sub_id}" \
    --query "[].roleDefinitionName" -o tsv | sed 's/^/    /' || true
else
  warn "サインイン中のユーザー情報を取得できなかった。サービスプリンシパルで実行している可能性がある"
fi

log "管理グループへのアクセス:"
if az account management-group list -o none 2>/dev/null; then
  echo "    利用可能"
else
  warn "管理グループを列挙できない。第2章・第4章の手順は実行できない"
  warn "テナントルートでの昇格、または Management Group Contributor の付与が必要"
fi

log "未登録のリソースプロバイダー (第1章の壊す演習で使える候補):"
az provider list --query "[?registrationState=='NotRegistered'].namespace" -o tsv 2>/dev/null \
  | head -10 | sed 's/^/    /' || warn "プロバイダー一覧を取得できなかった"

log "確認完了"

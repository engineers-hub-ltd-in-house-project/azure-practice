#!/usr/bin/env bash
# 第 4 章のクリーンアップ演習。
#
# 削除の順序に意味がある。管理グループは空でないと削除できないため、
# 先にサブスクリプションをテナントルート管理グループへ戻す必要がある。
# また、リソースグループを消してもユーザー割り当てマネージド ID の
# サービスプリンシパルは Entra ID 側に残りうる。本文はその観察を演習にする。

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

prefix="${AZP_PREFIX}"
chapter="ch04"
rg="${prefix}-${chapter}-rg"
mg="${prefix}-${chapter}-mg"

require_cmd az
confirm_subscription

sub_id=$(az account show --query id -o tsv)
tenant_id=$(az account show --query tenantId -o tsv)

# 削除前に、あとで「何が残ったか」を照合するための識別子を控える
identity_principal=$(az identity show --name "${prefix}-${chapter}-id" --resource-group "$rg" \
  --query principalId -o tsv 2>/dev/null || echo "")
if [[ -n "$identity_principal" ]]; then
  log "削除前のマネージド ID の principalId: ${identity_principal}"
  log "リソースグループ削除後、この ID が Entra ID 側に残っているかを確認する"
fi

log "リソースグループ ${rg} を削除する"
az group delete --name "$rg" --yes --no-wait 2>/dev/null || warn "リソースグループが存在しない"

log "リソースグループの削除完了を待つ"
az group wait --name "$rg" --deleted --timeout 900 2>/dev/null || true

if [[ -n "$identity_principal" ]]; then
  log "Entra ID 側にサービスプリンシパルが残っているかを確認する"
  if az ad sp show --id "$identity_principal" -o none 2>/dev/null; then
    warn "サービスプリンシパルはまだ存在する。反映には時間がかかる場合がある"
  else
    log "サービスプリンシパルも削除された"
  fi
fi

# 管理グループは空でないと削除できない。先にサブスクリプションを戻す。
if az account management-group show --name "$mg" -o none 2>/dev/null; then
  log "サブスクリプションをテナントルート管理グループへ戻す"
  az account management-group subscription add --name "$tenant_id" --subscription "$sub_id" -o none \
    || warn "テナントルートへの移動に失敗した"
  log "管理グループ ${mg} を削除する"
  az account management-group delete --name "$mg" -o none \
    || warn "管理グループを削除できなかった。中身が空か確認する"
fi

log "クリーンアップ完了"

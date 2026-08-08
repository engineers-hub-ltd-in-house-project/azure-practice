#!/usr/bin/env bash
# ハンズオンの前提が揃っているかを確認する。リソースは作らない。
# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_cmd az

log "Azure CLI: $(az version --query '"azure-cli"' -o tsv)"
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
# 列挙にはテナントルートでの read 権限が要るが、作成は既定では一般ユーザーにも許可されている
# （Entra の「階層設定」で制限されていない限り）。列挙の可否と作成の可否は別物なので分けて調べる。
if az account management-group list -o none 2>/dev/null; then
  echo "    列挙: 可能"
else
  echo "    列挙: 不可 (テナントルートの read 権限がない。ハンズオンには影響しない)"
fi
# 管理グループの作成は伝播の都合で一時的に AuthorizationFailed を返すことがある
# （実機検証で確認済み。同じ呼び出しが数十秒後に成功する）。リトライしてから判定する。
probe_name="azp-probe-$RANDOM"
probe_create() {
  az account management-group create --name "$probe_name" --display-name "azp probe" -o none 2>/dev/null
}
if retry 3 20 probe_create; then
  echo "    作成: 可能 (第2章・第4章の手順を実行できる)"
  az account management-group delete --name "$probe_name" -o none 2>/dev/null ||     warn "プローブ ${probe_name} を削除できなかった。手で削除すること"
else
  warn "管理グループを作成できない。第2章・第4章の該当手順は blocked になる"
  warn "テナントの階層設定で作成が制限されているか、昇格が必要"
fi

log "未登録のリソースプロバイダー (第1章の壊す演習で使える候補):"
az provider list --query "[?registrationState=='NotRegistered'].namespace" -o tsv 2>/dev/null \
  | head -10 | sed 's/^/    /' || warn "プロバイダー一覧を取得できなかった"

log "確認完了"

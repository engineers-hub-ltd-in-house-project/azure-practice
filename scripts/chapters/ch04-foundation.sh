#!/usr/bin/env bash
# 第4章 [統合ハンズオン] 4 階層を 1 つのシナリオで通しで作る
#
# 管理グループ → サブスクリプション配置 → リソースグループ → リソース、を通しで作る。
# 本文はこのスクリプトの各ステップを引用しながら説明する。読者が実行する対象と
# 本文が説明する対象を一致させるため、コマンドの実体はここにしか置かない。

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
prefix="${AZP_PREFIX}"
location="${AZP_LOCATION}"
chapter="ch04"

require_cmd az
confirm_subscription

sub_id=$(az account show --query id -o tsv)
mg_name="${prefix}-${chapter}-mg"

# --- 第1階層と第2階層: 管理グループ ---
# 管理グループはテナントに属する。サブスクリプションの中にあるのではない。
# ここで作った管理グループは、テナントルート管理グループの子になる。
# 管理グループの作成は、直前に別の管理グループを操作した直後だと一時的に失敗することがある
# （実機検証で確認済み）。権限エラーと区別するため、少し待って再試行する。
create_mg() {
  az account management-group create --name "$mg_name" --display-name "azure-practice 第4章" -o none 2>/dev/null
}
log "管理グループ ${mg_name} を作る"
if retry 3 15 create_mg; then
  log "作成した"
else
  warn "管理グループを作成できなかった。権限が不足している可能性がある"
  warn "テナントルートでの昇格、または Management Group Contributor が必要"
  warn "この階層をスキップして続行する。第2章・第4章の該当手順は blocked として記録すること"
  mg_name=""
fi

# --- 第3階層: サブスクリプションを管理グループの下に置く ---
# サブスクリプションの「移動」は、課金の付け替えではなく、
# ポリシーと RBAC の継承経路の付け替えである。
if [[ -n "$mg_name" ]]; then
  log "サブスクリプション ${sub_id} を ${mg_name} の下に置く"
  az account management-group subscription add --name "$mg_name" --subscription "$sub_id" -o none
fi

# --- 第4階層とリソース: Bicep をサブスクリプションスコープにデプロイする ---
# リソースグループの作成自体がサブスクリプションスコープの操作であることに注意。
log "リソースグループとリソースをデプロイする"
az deployment sub create \
  --name "${prefix}-${chapter}-$(date +%Y%m%d%H%M%S)" \
  --location "$location" \
  --template-file "$root/infra/bicep/chapters/ch04-foundation/main.bicep" \
  --parameters "$root/infra/bicep/chapters/ch04-foundation/main.parameters.json" \
  --parameters prefix="$prefix" location="$location" chapter="$chapter" \
  -o table

log "完了した。scripts/verify/ch04-foundation.sh で状態を確認する"

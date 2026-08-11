#!/usr/bin/env bash
# 第 7 章 マネージド ID ― リソース間の内向き認証
#
# シナリオ: コンテナーが、キーもパスワードも持たずにストレージのファイルを読む。
# ユーザー割り当てマネージド ID を載せ先より先に作り、権限まで割り当ててから
# コンテナーを作る。コンテナーの中では IMDS からトークンを取得して読む。

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

prefix="${AZP_PREFIX}"
location="${AZP_LOCATION}"
chapter="ch07"
rg="${prefix}-${chapter}-rg"

require_cmd az
confirm_subscription

sub_id=$(az account show --query id -o tsv)

# --- 1. 器を用意する ---
log "リソースグループ ${rg} を作る"
az group create --name "$rg" --location "$location" \
  --tags azp-book=azure-practice azp-chapter="$chapter" azp-lifecycle=ephemeral -o none

# --- 2. 載せ先より先に ID を作る ---
log "ユーザー割り当てマネージド ID を作る"
az identity create --name "${prefix}-${chapter}-uid" --resource-group "$rg" -o none
uid_pid=$(az identity show --name "${prefix}-${chapter}-uid" --resource-group "$rg" \
  --query principalId -o tsv)
uid_client=$(az identity show --name "${prefix}-${chapter}-uid" --resource-group "$rg" \
  --query clientId -o tsv)

# --- 3. 読ませる対象を作る ---
sa="${prefix}${chapter}$(echo "$sub_id" | tr -d - | cut -c1-8)"
scope="/subscriptions/${sub_id}/resourceGroups/${rg}/providers/Microsoft.Storage/storageAccounts/${sa}"
log "ストレージアカウント ${sa} を作る"
az storage account create --name "$sa" --resource-group "$rg" --location "$location" \
  --sku Standard_LRS --allow-blob-public-access false -o none

# --- 4. 自分にもファイルを扱うロールを割り当てる（管理の権限とは別） ---
log "自分に Storage Blob Data Contributor を割り当てる"
me=$(az ad signed-in-user show --query id -o tsv)
assign_me() {
  az role assignment create --assignee "$me" --role "Storage Blob Data Contributor" \
    --scope "$scope" -o none 2>/dev/null
}
retry 3 20 assign_me

log "コンテナーを作り、読ませるファイルを 1 つ置く"
put_file() {
  az storage container create --name docs --account-name "$sa" --auth-mode login -o none \
    && az storage blob upload --account-name "$sa" --container-name docs \
      --name sample.txt --file "$1" --auth-mode login --overwrite -o none
}
tmp=$(mktemp)
echo "hello from managed identity" > "$tmp"
retry 5 20 put_file "$tmp"
rm -f "$tmp"

# --- 5. 載せ先がまだ無い時点で、ID に権限を割り当てる ---
log "ユーザー割り当て ID に Storage Blob Data Reader を割り当てる"
assign_uid() {
  az role assignment create --assignee-object-id "$uid_pid" \
    --assignee-principal-type ServicePrincipal \
    --role "Storage Blob Data Reader" --scope "$scope" -o none 2>/dev/null
}
retry 3 20 assign_uid

# --- 6. 載せ先を作る。2 種類の ID を同時に載せて動かす ---
uid_id="/subscriptions/${sub_id}/resourceGroups/${rg}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${prefix}-${chapter}-uid"
imds="http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fstorage.azure.com%2F"
inner="curl -s -H 'Metadata: true' '${imds}'; echo; \
curl -s -H 'Metadata: true' '${imds}&client_id=${uid_client}'; echo; \
az login --identity --client-id ${uid_client} -o none; \
az storage blob list --account-name ${sa} --container-name docs --auth-mode login -o table"

log "コンテナーインスタンスを作る（システム割り当てとユーザー割り当ての両方を載せる）"
az container create --name "${prefix}-${chapter}-aci" --resource-group "$rg" \
  --image mcr.microsoft.com/azure-cli:latest \
  --assign-identity "[system]" "$uid_id" \
  --restart-policy Never --os-type Linux --cpu 1 --memory 1 \
  --command-line "/bin/sh -c \"$inner\"" -o none

log "実行の終了を待つ"
finished_state() {
  local s
  for _ in $(seq 1 60); do
    s=$(az container show --name "${prefix}-${chapter}-aci" --resource-group "$rg" \
      --query instanceView.state -o tsv 2>/dev/null || true)
    if [[ "$s" == "Succeeded" || "$s" == "Failed" ]]; then
      echo "$s"
      return 0
    fi
    sleep 10
  done
  echo "Timeout"
}

# ロール割り当ての伝播が間に合わないと 1 回目は権限エラーで終わる。停止した
# コンテナーを起動し直すと同じコマンドがもう一度走る。
if [[ "$(finished_state)" != "Succeeded" ]]; then
  warn "1 回目は失敗した。ロール割り当ての伝播を待って実行し直す"
  sleep 60
  az container start --name "${prefix}-${chapter}-aci" --resource-group "$rg" -o none
  [[ "$(finished_state)" == "Succeeded" ]] || die "2 回目も失敗した。az container logs で原因を確認する"
fi

log "コンテナーの出力"
az container logs --name "${prefix}-${chapter}-aci" --resource-group "$rg"

log "完了。後始末は scripts/teardown/ch07-managed-identity.sh"

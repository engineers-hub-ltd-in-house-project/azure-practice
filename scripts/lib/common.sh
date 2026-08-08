#!/usr/bin/env bash
# 全スクリプト共通の前提。各スクリプトの冒頭で source する。
# 本書のハンズオンが顧客環境や本番サブスクリプションで走ることを防ぐガードもここに置く。

set -euo pipefail

# 本書のハンズオンが使う既定値。上書きしたい場合は環境変数で渡す。
: "${AZP_LOCATION:=japaneast}"
: "${AZP_PREFIX:=azp}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m警告:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mエラー:\033[0m %s\n' "$*" >&2; exit 1; }

require_cmd() {
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "$c が見つからない"
  done
}

# ログイン中のサブスクリプションを表示し、続行の確認を取る。
# 本番環境で誤って実行することを防ぐための最後の関門。
confirm_subscription() {
  require_cmd az
  local name id user
  name=$(az account show --query name -o tsv 2>/dev/null) || die "az login が済んでいない"
  id=$(az account show --query id -o tsv)
  user=$(az account show --query user.name -o tsv)

  log "サブスクリプション: ${name} (${id})"
  log "ユーザー: ${user}"

  if [[ "${AZP_ASSUME_YES:-}" == "1" ]]; then
    return 0
  fi
  read -r -p "このサブスクリプションでハンズオンを実行する。よいか [y/N]: " answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] || die "中止した"
}

# RBAC の割り当ては即座には伝播しない。verify スクリプトはこれで待つ。
retry() {
  local attempts="$1"; shift
  local delay="$1"; shift
  local i=1
  until "$@"; do
    if (( i >= attempts )); then
      return 1
    fi
    warn "失敗した。${delay} 秒後に再試行する (${i}/${attempts})"
    sleep "$delay"
    i=$(( i + 1 ))
  done
  return 0
}

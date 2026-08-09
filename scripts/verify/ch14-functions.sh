#!/usr/bin/env bash
# 第 14 章の期待状態を read-only で検証する。冪等。

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_cmd az
rg="azp-ch14-rg"
failed=0

log "第14章の状態を検証する"

tier=$(az appservice plan list -g "$rg" --query "[0].sku.tier" -o tsv 2>/dev/null || echo missing)
if [[ "$tier" == "FlexConsumption" ]]; then
  printf '  OK   プランの tier が FlexConsumption である\n'
else
  printf '  NG   プランの tier が %s である\n' "$tier"
  failed=1
fi

mem=$(az functionapp scale config show --name azp-ch14-func -g "$rg" \
  --query instanceMemoryMB -o tsv 2>/dev/null || echo missing)
if [[ "$mem" == "2048" ]]; then
  printf '  OK   インスタンスメモリが既定の 2048MB である\n'
else
  printf '  NG   インスタンスメモリが %s である\n' "$mem"
  failed=1
fi

ar=$(az functionapp scale config show --name azp-ch14-func -g "$rg" \
  --query "length(alwaysReady)" -o tsv 2>/dev/null || echo missing)
if [[ "$ar" == "0" ]]; then
  printf '  OK   Always Ready は 0（アイドル時の課金なし）である\n'
else
  printf '  NG   Always Ready の設定が %s 件ある\n' "$ar"
  failed=1
fi

if (( failed == 0 )); then
  log "検証に成功した"
else
  die "検証に失敗した項目がある"
fi

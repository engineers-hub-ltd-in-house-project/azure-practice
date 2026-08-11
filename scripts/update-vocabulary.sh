#!/usr/bin/env bash
# 語彙スナップショットを更新する。新語を本書の語彙として抱える、という判断を明示するための入口。
#
# 差分を表示してから書き込む。表示された語に造語が混ざっていないかを、ここで必ず見る。
# 見ないで通すなら、この仕組みは無いのと同じである。

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
snapshot="$root/docs/vocabulary-snapshot.txt"

new_list=$(node "$root/scripts/lint/vocabulary-tokens.mjs")

if [[ -f "$snapshot" ]]; then
  added=$(comm -13 <(grep -v '^#' "$snapshot" | grep -v '^$' | sort) <(echo "$new_list" | sort))
  removed=$(comm -23 <(grep -v '^#' "$snapshot" | grep -v '^$' | sort) <(echo "$new_list" | sort))
  if [[ -n "$added" ]]; then
    log "増える語（造語が混ざっていないかを確かめる）"
    while IFS= read -r word; do printf '  + %s\n' "$word"; done <<< "$added"
  fi
  if [[ -n "$removed" ]]; then
    log "消える語"
    while IFS= read -r word; do printf '  - %s\n' "$word"; done <<< "$removed"
  fi
  if [[ -z "$added" && -z "$removed" ]]; then
    log "差分なし"
    exit 0
  fi
fi

{
  echo "# 本書の語彙スナップショット。scripts/update-vocabulary.sh が生成する。手で編集しない。"
  echo "# ここに無い語が原稿に出ると vocab-lint が落ちる。新語は言い換えを検討してから足す。"
  echo "$new_list" | sort
} > "$snapshot"

log "docs/vocabulary-snapshot.txt を更新した（$(echo "$new_list" | wc -l | tr -d ' ') 語）"

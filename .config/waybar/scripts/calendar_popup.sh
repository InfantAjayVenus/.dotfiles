#!/usr/bin/env bash

set -euo pipefail

tz="Asia/Kolkata"
offset=0

render() {
  clear
  local base_date view_date month year
  base_date="$(TZ="${tz}" date '+%Y-%m-15')"
  view_date="$(TZ="${tz}" date -d "${base_date} ${offset} month" '+%Y-%m-15')"
  month="$(TZ="${tz}" date -d "${view_date}" '+%m')"
  year="$(TZ="${tz}" date -d "${view_date}" '+%Y')"

  printf '\n'
  cal "${month#0}" "${year}"
  printf '\n'
  printf '  h/Left: prev month   l/Right: next month\n'
  printf '  t: today             q/Esc: close\n'
}

read_key() {
  local key
  IFS= read -rsn1 key || return 1
  if [[ "${key}" == $'\x1b' ]]; then
    IFS= read -rsn2 -t 0.01 rest || true
    key+="${rest:-}"
  fi
  printf '%s' "${key}"
}

render
while true; do
  key="$(read_key)" || exit 0
  case "${key}" in
    h|$'\x1b[D')
      offset=$((offset - 1))
      render
      ;;
    l|$'\x1b[C')
      offset=$((offset + 1))
      render
      ;;
    t)
      offset=0
      render
      ;;
    q|$'\x1b')
      exit 0
      ;;
  esac
done

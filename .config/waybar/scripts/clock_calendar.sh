#!/usr/bin/env bash

set -euo pipefail

state_file="/tmp/waybar-clock-calendar.offset"
tz="Asia/Kolkata"
action="${1:-render}"

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\t'/\\t}"
  printf '%s' "${s}"
}

read_offset() {
  if [[ -f "${state_file}" ]]; then
    cat "${state_file}"
  else
    printf '0\n'
  fi
}

write_offset() {
  printf '%s\n' "$1" > "${state_file}"
}

case "${action}" in
  shift_up)
    offset="$(read_offset)"
    write_offset "$((offset - 1))"
    exit 0
    ;;
  shift_down)
    offset="$(read_offset)"
    write_offset "$((offset + 1))"
    exit 0
    ;;
  reset)
    write_offset 0
    exit 0
    ;;
  render)
    ;;
  *)
    exit 1
    ;;
esac

offset="$(read_offset)"
base_date="$(TZ="${tz}" date '+%Y-%m-15')"
view_date="$(TZ="${tz}" date -d "${base_date} ${offset} month" '+%Y-%m-15')"
time_text="$(TZ="${tz}" date '+%H:%M  -  %a, %d')"
month_title="$(TZ="${tz}" date -d "${view_date}" '+%B %Y')"
cal_text="$(cal "$(TZ="${tz}" date -d "${view_date}" '+%m')" "$(TZ="${tz}" date -d "${view_date}" '+%Y')")"

tooltip="$(printf '<tt><small><span color="#99d1db"><b>%s</b></span>\n%s\n\n<span color="#babbf1">Scroll: navigate months</span>\n<span color="#babbf1">Right click: reset</span></small></tt>' "${month_title}" "${cal_text}")"

printf '{"text":"%s","tooltip":"%s"}\n' "$(json_escape "${time_text}")" "$(json_escape "${tooltip}")"

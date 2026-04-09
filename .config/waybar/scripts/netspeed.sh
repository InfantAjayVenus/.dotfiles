#!/usr/bin/env bash

set -euo pipefail

state_prefix="/tmp/waybar-netspeed"

format_rate() {
  local bytes_per_sec="$1"
  awk -v bps="${bytes_per_sec}" '
    BEGIN {
      split("B/s KB/s MB/s GB/s", units, " ")
      value = bps
      unit = 1
      while (value >= 1024 && unit < 4) {
        value /= 1024
        unit += 1
      }
      if (value >= 100 || unit == 1) {
        printf "%.0f%s", value, units[unit]
      } else {
        printf "%.1f%s", value, units[unit]
      }
    }
  '
}

iface="$(awk '$2 == "00000000" { print $1; exit }' /proc/net/route)"
if [[ -z "${iface}" ]]; then
  for candidate in /sys/class/net/*; do
    candidate="${candidate##*/}"
    if [[ "${candidate}" == "lo" ]]; then
      continue
    fi
    if [[ -r "/sys/class/net/${candidate}/operstate" ]] && [[ "$(<"/sys/class/net/${candidate}/operstate")" == "up" ]]; then
      iface="${candidate}"
      break
    fi
  done
fi
if [[ -z "${iface}" ]]; then
  iface="$(awk -F: '$1 !~ /lo/ { gsub(/ /, "", $1); print $1; exit }' /proc/net/dev)"
fi

if [[ -z "${iface}" ]] || [[ ! -r "/sys/class/net/${iface}/statistics/rx_bytes" ]]; then
  printf '{"text":"↓ 0B/s ↑ 0B/s","tooltip":"No active network interface found"}\n'
  exit 0
fi

rx_bytes="$(<"/sys/class/net/${iface}/statistics/rx_bytes")"
tx_bytes="$(<"/sys/class/net/${iface}/statistics/tx_bytes")"
now="$(date +%s)"
state_file="${state_prefix}.${iface}"

down_rate=0
up_rate=0
if [[ -f "${state_file}" ]]; then
  read -r prev_time prev_rx prev_tx < "${state_file}" || true
  if [[ -n "${prev_time:-}" && -n "${prev_rx:-}" && -n "${prev_tx:-}" ]]; then
    elapsed=$((now - prev_time))
    if (( elapsed > 0 )); then
      down_delta=$((rx_bytes - prev_rx))
      up_delta=$((tx_bytes - prev_tx))
      if (( down_delta < 0 )); then down_delta=0; fi
      if (( up_delta < 0 )); then up_delta=0; fi
      down_rate=$((down_delta / elapsed))
      up_rate=$((up_delta / elapsed))
    fi
  fi
fi
printf '%s %s %s\n' "${now}" "${rx_bytes}" "${tx_bytes}" > "${state_file}"

down_text="$(format_rate "${down_rate}")"
up_text="$(format_rate "${up_rate}")"

printf '{"text":"↓ %s ↑ %s","tooltip":"Interface: %s\\nDownload: %s\\nUpload: %s"}\n' \
  "${down_text}" "${up_text}" "${iface}" "${down_text}" "${up_text}"

#!/usr/bin/env bash

set -euo pipefail

if ! command -v sensors >/dev/null 2>&1; then
  printf '{"text":" N/A","tooltip":"lm_sensors not installed"}\n'
  exit 0
fi

core_lines="$(sensors | awk '/^Core [0-9]+:/ { value=$3; gsub(/^\+/, "", value); gsub(/°C/, "", value); print $1 " " $2 " " value }')"

if [[ -z "${core_lines}" ]]; then
  printf '{"text":" N/A","tooltip":"No core temperature sensors found"}\n'
  exit 0
fi

text="$(printf '%s\n' "${core_lines}" | awk '{printf "%s%s°C", sep, $3; sep=" "}')"
tooltip="$(printf '%s\n' "${core_lines}" | awk 'BEGIN { first=1 } { if (!first) printf "\\n"; first=0; printf "%s %s %s°C", $1, $2, $3 }')"

printf '{"text":" %s","tooltip":"%s"}\n' "${text}" "${tooltip}"

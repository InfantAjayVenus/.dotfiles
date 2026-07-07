#!/bin/bash

# Directory and file paths
TODO_DIR="$HOME/.config/waybar/scripts/todo"
CONF_FILE="$TODO_DIR/todo.conf"
TUI_SCRIPT="$TODO_DIR/todo_tui.sh"
CLI_SCRIPT="$TODO_DIR/todo_cli.sh"
touch "$CONF_FILE"

# Source the configuration file
[ -s "$CONF_FILE" ] && source "$CONF_FILE"

# --- Function to update a key-value pair in the config file ---
update_config() {
  local key="$1"
  local value="$2"
  sed -i "s/^\($key\s*=\s*\).*/\1\"$value\"/" "$CONF_FILE"
}

# --- Daily Auto-Delete Logic ---
if [[ -n "$SCHEDULED_ACTION" && "$SCHEDULED_ACTION" != "none" ]]; then
  current_ts=$(date +%s)
  scheduled_ts_today=$(date -d "$SCHEDULED_TIME" +%s 2>/dev/null)
  if [[ -n "$scheduled_ts_today" ]]; then
    if ((current_ts > scheduled_ts_today)) && ((LAST_CHECKED_TIMESTAMP < scheduled_ts_today)); then
      if [[ "$SCHEDULED_ACTION" == "all" ]]; then
        "$CLI_SCRIPT" delete-all
      elif [[ "$SCHEDULED_ACTION" == "completed" ]]; then
        "$CLI_SCRIPT" delete-completed
      fi
      update_config "LAST_CHECKED_TIMESTAMP" "$current_ts"
    fi
  fi
fi

# --- Handle Click Actions ---
case "$1" in
mark_done)
  idx=$("$CLI_SCRIPT" get-highest-priority)
  if [[ "$idx" -ne -1 ]]; then
    "$CLI_SCRIPT" toggle "$idx"
  fi
  exit 0
  ;;
open_tui)
  kitty -e "$TUI_SCRIPT"
  exit 0
  ;;
middle_click)
  if [[ "$MIDDLE_CLICK_ACTION" == "all" ]]; then
    "$CLI_SCRIPT" delete-all
  elif [[ "$MIDDLE_CLICK_ACTION" == "completed" ]]; then
    "$CLI_SCRIPT" delete-completed
  fi
  exit 0
  ;;
esac

# --- Generate Waybar JSON Output ---
raw_tasks=$("$CLI_SCRIPT" get-raw)
current_task_line=$(grep '^[^|]*|0|' <<< "$raw_tasks" | sort -n -t'|' -k1 | head -n 1)
tooltip=""
pending_count=$(grep -c '^[^|]*|0|' <<< "$raw_tasks" 2>/dev/null || echo 0)
total_count=$(grep -c '^[^|]*|' <<< "$raw_tasks" 2>/dev/null || echo 0)

if [[ -z "$raw_tasks" ]]; then
  bar_text="0/0"
  tooltip="Right-click to add a new task"
else
  bar_text="${pending_count}/${total_count}"

  if [[ -n "$current_task_line" ]]; then
    tooltip="<b><u>Top 3 Tasks</u></b>\n"
    count=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" ]] && continue
      desc=$(echo "$line" | cut -d'|' -f3)
      count=$((count + 1))
      tooltip+="$count. $desc\n"
      [[ "$count" -ge 3 ]] && break
    done < <(grep '^[^|]*|0|' <<< "$raw_tasks" | sort -n -t'|' -k1)

    if (( pending_count > 3 )); then
      tooltip+="\n<i>+$((pending_count - 3)) more</i>"
    fi
  else
    tooltip="<b>All tasks cleared. Great job!</b>"
  fi
fi

# --- Final JSON Output ---
bar_text_json=$(echo "\u00a0\u00a0$bar_text" | sed 's/"/\\"/g')
tooltip_json=$(echo -e "$tooltip" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

printf '{"text": "%s", "tooltip": "%s"}\n' "$bar_text_json" "$tooltip_json"

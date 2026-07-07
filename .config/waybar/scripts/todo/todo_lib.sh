#!/bin/bash

# Directory and file paths
TODO_DIR="$HOME/.config/waybar/scripts/todo"
TASK_FILE="$TODO_DIR/tasks.txt"
CONF_FILE="$TODO_DIR/todo.conf"
TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

ensure_config_exists() {
    if [[ ! -f "$CONF_FILE" ]]; then
        cat > "$CONF_FILE" << EOF
# Configuration for the todo script
SCHEDULED_TIME="none"
SCHEDULED_ACTION="none"
LAST_CHECKED_TIMESTAMP="0"
MIDDLE_CLICK_ACTION="none"
EOF
    fi
}

update_config() {
    local key="$1"
    local value="$2"
    if grep -q "^$key=" "$CONF_FILE"; then
        sed -i "s/^\($key\s*=\s*\).*/\1\"$value\"/" "$CONF_FILE"
    else
        echo "$key=\"$value\"" >> "$CONF_FILE"
    fi
}

sort_tasks() {
    sort -t'|' -k2,2n -k1,1n "$TASK_FILE" -o "$TASK_FILE"
}

normalize_pending_priorities() {
    awk -F'|' '
    BEGIN { OFS="|"; pending_prio = 0 }
    $2 == 0 { $1 = ++pending_prio }
    { print $0 }
    ' "$TASK_FILE" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$TASK_FILE"
    sort_tasks
}

add_task() { 
    local desc="$1"
    local prio="$2"
    local choice="$3"

    if [[ ! "$desc" =~ @[A-Za-z]{3},[[:space:]][0-9]{1,2}-[A-Za-z]{3}-[0-9]{2} ]]; then
        local created_date
        created_date=$(date +"@%a, %-d-%b-%y")
        desc="$desc $created_date"
    fi

    local conflict_line
    conflict_line=$(grep "^${prio}|" "$TASK_FILE")

    if [[ -n "$conflict_line" ]]; then
        awk -F'|' -v new_prio="$prio" -v new_desc="$desc" -v choice="$choice" '
        BEGIN { OFS="|" }
        {
            current_prio = $1
            if (choice ~ /^[Yy]/) {
                if (current_prio >= new_prio) { $1 = current_prio + 1 }
            } else {
                if (current_prio > new_prio) { $1 = current_prio + 1 }
            }
            print $0
        }' "$TASK_FILE" > "$TEMP_FILE"

        if [[ "$choice" =~ ^[Yy]$ ]]; then
            echo "$prio|0|$desc" >> "$TEMP_FILE"
        else
            echo "$((prio + 1))|0|$desc" >> "$TEMP_FILE"
        fi
    else
        cp "$TASK_FILE" "$TEMP_FILE"
        echo "$prio|0|$desc" >> "$TEMP_FILE"
    fi
    sort -t'|' -k2,2n -k1,1n "$TEMP_FILE" -o "$TASK_FILE"
}

delete_task() {
    local num="$1"
    sed -i "${num}d" "$TASK_FILE"
    sort_tasks
}

toggle_status() {
    local num="$1"
    local line_to_toggle
    line_to_toggle=$(sed -n "${num}p" "$TASK_FILE")
    local status
    status=$(echo "$line_to_toggle" | cut -d'|' -f2)
    local new_line
    if [[ "$status" -eq 0 ]]; then
        new_line=$(echo "$line_to_toggle" | sed 's/|0|/|1|/')
    else
        new_line=$(echo "$line_to_toggle" | sed 's/|1|/|0|/')
    fi
    sed -i "${num}s/.*/$new_line/" "$TASK_FILE"
    sort_tasks
}

edit_task() {
    local num="$1"
    local new_prio="$2"
    local new_desc="$3"
    local current_status="$4"

    local old_line old_desc creation_date
    old_line=$(sed -n "${num}p" "$TASK_FILE")
    old_desc=$(echo "$old_line" | cut -d'|' -f3-)

    if [[ "$old_desc" =~ @[A-Za-z]{3},[[:space:]][0-9]{1,2}-[A-Za-z]{3}-[0-9]{2} ]]; then
        creation_date="${BASH_REMATCH[0]}"
        if [[ ! "$new_desc" =~ "$creation_date" ]]; then
            new_desc="$new_desc $creation_date"
        fi
    fi

    awk -F'|' -v row="$num" -v prio="$new_prio" -v status="$current_status" -v desc="$new_desc" '
    BEGIN { OFS="|" }
    NR == row { print prio, status, desc; next }
    { print $0 }
    ' "$TASK_FILE" > "$TEMP_FILE"

    sort -t'|' -k2,2n -k1,1n "$TEMP_FILE" -o "$TASK_FILE"
}

delete_all_tasks() {
    > "$TASK_FILE"
}

delete_completed_tasks() {
    sed -i '/|1|/d' "$TASK_FILE"
    normalize_pending_priorities
}

get_highest_priority_task_index() {
    local idx
    idx=$(awk -F'|' '$2 == 0 {print NR; exit}' "$TASK_FILE")
    if [[ -n "$idx" ]]; then
        echo "$idx"
    else
        echo "-1"
    fi
}

get_raw_tasks() {
    if [[ -f "$TASK_FILE" ]]; then
        cat "$TASK_FILE"
    fi
}

is_task_file_empty() {
    [[ ! -s "$TASK_FILE" ]]
}

get_task_line() {
    local num="$1"
    sed -n "${num}p" "$TASK_FILE"
}

task_exists() {
    local num="$1"
    [[ -n "$(get_task_line "$num")" ]]
}

get_next_priority() {
    local last_incomplete_prio
    last_incomplete_prio=$(awk -F'|' '$2 == 0 {prio=$1} END {print prio}' "$TASK_FILE")
    if [[ -z "$last_incomplete_prio" ]]; then
        echo 1
    else
        echo $((last_incomplete_prio + 1))
    fi
}

has_priority_conflict() {
    local prio="$1"
    grep -q "^${prio}|" "$TASK_FILE"
}

get_conflict_line() {
    local prio="$1"
    grep "^${prio}|" "$TASK_FILE"
}

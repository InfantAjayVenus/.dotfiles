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

display_tasks() {
    clear
    echo "--- Your Todo List ---"
    if [[ ! -s "$TASK_FILE" ]]; then
        echo "No tasks yet!"
    else
        awk -F'|' '{
            if ($2 == 1) {
                printf "\033[90m%d. [✔] %s (Prio: %d)\033[0m\n", NR, $3, $1
            } else {
                printf "%d. [ ] %s (Prio: %d)\n", NR, $3, $1
            }
        }' "$TASK_FILE"
    fi
    echo "----------------------"
}

# --- Core Logic Functions ---
add_task() { 
    read -rp "Enter new task description: " desc
    if [[ -z "$desc" ]]; then echo "Description cannot be empty."; sleep 1; return; fi

    read -rp "Enter priority (number): " prio
    if ! [[ "$prio" =~ ^[0-9]+$ ]]; then echo "Priority must be a number."; sleep 1; return; fi

    conflict_line=$(grep "^${prio}|" "$TASK_FILE")

    if [[ -n "$conflict_line" ]]; then
        conflict_desc=$(echo "$conflict_line" | cut -d'|' -f3)
        read -rp "Task '$conflict_desc' has priority $prio. Make '$desc' more prior? (y/n) " choice
        
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
    local num="${1:-}"
    if [[ -z "$num" ]]; then
        read -rp "Enter task number to delete: " num
    fi
    if ! [[ "$num" =~ ^[0-9]+$ ]] || [[ "$num" -eq 0 ]]; then echo "Invalid number."; sleep 1; return; fi
    if [[ -z "$(sed -n "${num}p" "$TASK_FILE")" ]]; then echo "Task number not found."; sleep 1; return; fi
    sed -i "${num}d" "$TASK_FILE"
}

toggle_status() {
    local num="${1:-}"
    if [[ -z "$num" ]]; then
        read -rp "Enter task number to toggle complete/pending: " num
    fi
    if ! [[ "$num" =~ ^[0-9]+$ ]] || [[ "$num" -eq 0 ]]; then echo "Invalid number."; sleep 1; return; fi
    
    line_to_toggle=$(sed -n "${num}p" "$TASK_FILE")
    if [[ -z "$line_to_toggle" ]]; then echo "Task number not found."; sleep 1; return; fi
    
    status=$(echo "$line_to_toggle" | cut -d'|' -f2)
    
    if [[ "$status" -eq 0 ]]; then
        new_line=$(echo "$line_to_toggle" | sed 's/|0|/|1|/')
    else
        new_line=$(echo "$line_to_toggle" | sed 's/|1|/|0|/')
    fi
    sed -i "${num}s/.*/$new_line/" "$TASK_FILE"
}

edit_task() {
    local num="${1:-}"
    if [[ -z "$num" ]]; then
        read -rp "Enter task number to edit: " num
    fi
    if ! [[ "$num" =~ ^[0-9]+$ ]] || [[ "$num" -eq 0 ]]; then echo "Invalid number."; sleep 1; return; fi

    line_to_edit=$(sed -n "${num}p" "$TASK_FILE")
    if [[ -z "$line_to_edit" ]]; then echo "Task number not found."; sleep 1; return; fi

    current_prio=$(echo "$line_to_edit" | cut -d'|' -f1)
    current_status=$(echo "$line_to_edit" | cut -d'|' -f2)
    current_desc=$(echo "$line_to_edit" | cut -d'|' -f3-)

    read -rp "Enter new description [$current_desc]: " new_desc
    new_desc="${new_desc:-$current_desc}"
    if [[ -z "$new_desc" ]]; then echo "Description cannot be empty."; sleep 1; return; fi

    read -rp "Enter new priority [$current_prio]: " new_prio
    new_prio="${new_prio:-$current_prio}"
    if ! [[ "$new_prio" =~ ^[0-9]+$ ]]; then echo "Priority must be a number."; sleep 1; return; fi

    awk -F'|' -v row="$num" -v prio="$new_prio" -v status="$current_status" -v desc="$new_desc" '
    BEGIN { OFS="|" }
    NR == row { print prio, status, desc; next }
    { print $0 }
    ' "$TASK_FILE" > "$TEMP_FILE"

    sort -t'|' -k2,2n -k1,1n "$TEMP_FILE" -o "$TASK_FILE"
}

# --- Settings Functions ---

delete_all_tasks_now() {
    read -rp "Are you sure you want to delete ALL tasks? This cannot be undone. (y/n) " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        > "$TASK_FILE"
        echo "All tasks deleted."
    else
        echo "Operation cancelled."
    fi
    sleep 1
}

delete_completed_tasks_now() {
    read -rp "Are you sure you want to delete all COMPLETED tasks? (y/n) " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        sed -i '/|1|/d' "$TASK_FILE"
        normalize_pending_priorities
        echo "Completed tasks deleted."
    else
        echo "Operation cancelled."
    fi
    sleep 1
}

set_auto_delete() {
    local time_input
    while true; do
        read -rp "Enter daily deletion time (e.g., 14:10, 2:10pm) or type 'disable': " time_input
        if [[ "$time_input" == "disable" ]]; then
            update_config "SCHEDULED_TIME" "none"
            update_config "SCHEDULED_ACTION" "none"
            echo "Auto-deletion disabled."
            sleep 1
            return
        fi

        valid_time=$(date -d "$time_input" +%H:%M)
        if [[ -n "$valid_time" ]]; then
            break
        else
            echo "Invalid time format. Please try again."
        fi
    done
    
    read -rp "What should be deleted daily at $valid_time? (1) Completed tasks, (2) ALL tasks: " action_choice
    case "$action_choice" in
        1)
            update_config "SCHEDULED_TIME" "$valid_time"
            update_config "SCHEDULED_ACTION" "completed"
            echo "Set to delete COMPLETED tasks daily at $valid_time."
            ;;
        2)
            update_config "SCHEDULED_TIME" "$valid_time"
            update_config "SCHEDULED_ACTION" "all"
            echo "Set to delete ALL tasks daily at $valid_time."
            ;;
        *)
            echo "Invalid option. No changes made."
            ;;
    esac
    sleep 2
}

set_middle_click() {
    echo "--- Middle-Click Configuration ---"
    echo "This sets the action performed when you middle-click the Waybar module."
    read -rp "Choose action: (1) Delete completed tasks, (2) Delete ALL tasks: " action_choice
    case "$action_choice" in
        1)
            update_config "MIDDLE_CLICK_ACTION" "completed"
            echo "Middle-click will now delete COMPLETED tasks."
            ;;
        2)
            update_config "MIDDLE_CLICK_ACTION" "all"
            echo "Middle-click will now delete ALL tasks."
            ;;
        *)
            echo "Invalid option. No changes made."
            ;;
    esac
    sleep 2
}

settings_menu() {
    local choice

    while true; do
        clear
        source "$CONF_FILE" 
        echo "--- Settings ---"
        echo "Auto-Delete: ${SCHEDULED_ACTION} at ${SCHEDULED_TIME}"
        echo "Middle-Click: Deletes ${MIDDLE_CLICK_ACTION:-none} tasks"
        echo "----------------"
        echo "(1) Delete ALL tasks now"
        echo "(2) Delete COMPLETED tasks now"
        echo "(3) Set daily auto-delete time"
        echo "(4) Configure middle-click action"
        echo "(b)ack to main menu"
        printf "Choose an option: "
        IFS= read -rsn1 choice
        echo

        case "$choice" in
            1) delete_all_tasks_now ;;
            2) delete_completed_tasks_now ;;
            3) set_auto_delete ;;
            4) set_middle_click ;;
            b|B) break ;;
            *) echo "Invalid option." ; sleep 1 ;;
        esac
    done
}

read_main_action() {
    local action remainder

    printf "Choose an option: "
    IFS= read -rsn1 action

    case "$action" in
        e|E|d|D|t|T)
            printf "%s" "$action"
            IFS= read -r remainder
            task_num="${remainder//[[:space:]]/}"
            if [[ -n "$task_num" && ! "$task_num" =~ ^[0-9]+$ ]]; then
                echo "Invalid task number."
                sleep 1
                action=""
                task_num=""
            fi
            ;;
        *)
            echo
            ;;
    esac

    choice="$action"
}


# --- Main Application Loop ---
ensure_config_exists
sort_tasks 
while true; do
    display_tasks
    echo "(a)dd | (e)dit[#] | (d)elete[#] | (t)oggle[#] | (s)ettings | (q)uit"
    choice=""
    task_num=""
    read_main_action

    action="$choice"

    case "$action" in
        a|A) add_task ;;
        e|E)
            if [[ -n "$task_num" && ! "$task_num" =~ ^[0-9]+$ ]]; then
                echo "Invalid task number."
                sleep 1
            else
                edit_task "$task_num"
            fi
            ;;
        d|D)
            if [[ -n "$task_num" && ! "$task_num" =~ ^[0-9]+$ ]]; then
                echo "Invalid task number."
                sleep 1
            else
                delete_task "$task_num"
            fi
            ;;
        t|T)
            if [[ -n "$task_num" && ! "$task_num" =~ ^[0-9]+$ ]]; then
                echo "Invalid task number."
                sleep 1
            else
                toggle_status "$task_num"
            fi
            ;;
        s|S)
            if [[ -n "$task_num" ]]; then
                echo "Settings does not take a task number."
                sleep 1
            else
                settings_menu
            fi
            ;;
        q|Q)
            if [[ -n "$task_num" ]]; then
                echo "Quit does not take a task number."
                sleep 1
            else
                break
            fi
            ;;
        *) echo "Invalid option." ; sleep 1 ;;
    esac
    sort_tasks 
done

clear

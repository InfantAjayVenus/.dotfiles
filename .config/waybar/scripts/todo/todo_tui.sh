#!/bin/bash

# Source the shared operations library
source "$(dirname "$0")/todo_lib.sh"

# Interactive mode: ensure new window open if stdin is not a terminal
if [[ -z "$TODO_TUI_INTERACTIVE_WINDOW" ]] && ! [[ -t 0 ]]; then
    export TODO_TUI_INTERACTIVE_WINDOW=1
    if command -v kitty >/dev/null 2>&1; then
        kitty -e "$0" &
    elif command -v alacritty >/dev/null 2>&1; then
        alacritty -e "$0" &
    elif command -v foot >/dev/null 2>&1; then
        foot -e "$0" &
    else
        kitty -e "$0" &
    fi
    exit 0
fi

# TUI display helper
display_tasks() {
    clear
    echo "--- Your Todo List ---"
    if is_task_file_empty; then
        echo "No tasks yet!"
    else
        get_raw_tasks | awk -F'|' '{
            if ($2 == 1) {
                printf "\033[90m%d. [✔] %s (Prio: %d)\033[0m\n", NR, $3, $1
            } else {
                printf "%d. [ ] %s (Prio: %d)\n", NR, $3, $1
            }
        }'
    fi
    echo "----------------------"
}

# --- Interactive Wrappers & Interactivity Functions ---

add_task_interactive() {
    read -rp "Enter new task description: " desc
    if [[ -z "$desc" ]]; then echo "Description cannot be empty."; sleep 1; return; fi

    read -rp "Enter priority (number): " prio
    if [[ -z "$prio" ]]; then
        prio=$(get_next_priority)
    elif ! [[ "$prio" =~ ^[0-9]+$ ]]; then
        echo "Priority must be a number."
        sleep 1
        return
    fi

    local choice=""
    local conflict_line
    conflict_line=$(get_conflict_line "$prio")

    if [[ -n "$conflict_line" ]]; then
        conflict_desc=$(echo "$conflict_line" | cut -d'|' -f3)
        read -rp "Task '$conflict_desc' has priority $prio. Make '$desc' more prior? (y/n) " choice
    fi

    add_task "$desc" "$prio" "$choice"
}

delete_task_interactive() {
    local num="${1:-}"
    if [[ -z "$num" ]]; then
        read -rp "Enter task number to delete: " num
    fi
    if ! [[ "$num" =~ ^[0-9]+$ ]] || [[ "$num" -eq 0 ]]; then echo "Invalid number."; sleep 1; return; fi
    if ! task_exists "$num"; then echo "Task number not found."; sleep 1; return; fi
    delete_task "$num"
}

toggle_status_interactive() {
    local num="${1:-}"
    if [[ -z "$num" ]]; then
        read -rp "Enter task number to toggle complete/pending: " num
    fi
    if ! [[ "$num" =~ ^[0-9]+$ ]] || [[ "$num" -eq 0 ]]; then echo "Invalid number."; sleep 1; return; fi
    if ! task_exists "$num"; then echo "Task number not found."; sleep 1; return; fi
    toggle_status "$num"
}

edit_task_interactive() {
    local num="${1:-}"
    if [[ -z "$num" ]]; then
        read -rp "Enter task number to edit: " num
    fi
    if ! [[ "$num" =~ ^[0-9]+$ ]] || [[ "$num" -eq 0 ]]; then echo "Invalid number."; sleep 1; return; fi

    local line_to_edit
    line_to_edit=$(get_task_line "$num")
    if [[ -z "$line_to_edit" ]]; then echo "Task number not found."; sleep 1; return; fi

    local current_prio current_status current_desc
    current_prio=$(echo "$line_to_edit" | cut -d'|' -f1)
    current_status=$(echo "$line_to_edit" | cut -d'|' -f2)
    current_desc=$(echo "$line_to_edit" | cut -d'|' -f3-)

    local display_desc="$current_desc"
    local creation_date=""
    if [[ "$current_desc" =~ @[A-Za-z]{3},[[:space:]][0-9]{1,2}-[A-Za-z]{3}-[0-9]{2} ]]; then
        creation_date="${BASH_REMATCH[0]}"
        display_desc="${current_desc% "$creation_date"}"
        display_desc="${display_desc%"$creation_date"}"
        display_desc=$(echo "$display_desc" | sed 's/[[:space:]]*$//')
    fi

    local new_desc
    read -rp "Enter new description [$display_desc]: " new_desc
    new_desc="${new_desc:-$display_desc}"
    if [[ -z "$new_desc" ]]; then echo "Description cannot be empty."; sleep 1; return; fi

    local new_prio
    read -rp "Enter new priority [$current_prio]: " new_prio
    new_prio="${new_prio:-$current_prio}"
    if ! [[ "$new_prio" =~ ^[0-9]+$ ]]; then echo "Priority must be a number."; sleep 1; return; fi

    edit_task "$num" "$new_prio" "$new_desc" "$current_status"
}

delete_all_tasks_now() {
    read -rp "Are you sure you want to delete ALL tasks? This cannot be undone. (y/n) " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        delete_all_tasks
        echo "All tasks deleted."
    else
        echo "Operation cancelled."
    fi
    sleep 1
}

delete_completed_tasks_now() {
    read -rp "Are you sure you want to delete all COMPLETED tasks? (y/n) " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        delete_completed_tasks
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
        a|A) add_task_interactive ;;
        e|E)
            if [[ -n "$task_num" && ! "$task_num" =~ ^[0-9]+$ ]]; then
                echo "Invalid task number."
                sleep 1
            else
                edit_task_interactive "$task_num"
            fi
            ;;
        d|D)
            if [[ -n "$task_num" && ! "$task_num" =~ ^[0-9]+$ ]]; then
                echo "Invalid task number."
                sleep 1
            else
                delete_task_interactive "$task_num"
            fi
            ;;
        t|T)
            if [[ -n "$task_num" && ! "$task_num" =~ ^[0-9]+$ ]]; then
                echo "Invalid task number."
                sleep 1
            else
                toggle_status_interactive "$task_num"
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

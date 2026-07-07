#!/bin/bash

# Source the shared operations library
source "$(dirname "$0")/todo_lib.sh"

ensure_config_exists

if [[ "$#" -eq 0 ]]; then
    echo "Error: No operation specified." >&2
    echo "Available operations: add, delete, toggle, edit, delete-all, delete-completed, get-highest-priority" >&2
    exit 1
fi

case "$1" in
    add)
        if [[ -z "$2" ]]; then
            echo "Error: Task description (argument 2) is required." >&2
            exit 1
        fi
        if [[ -z "$3" ]]; then
            echo "Error: Priority (argument 3) is required." >&2
            exit 1
        fi
        if ! [[ "$3" =~ ^[0-9]+$ ]]; then
            echo "Error: Priority must be a number." >&2
            exit 1
        fi
        if [[ -n "$4" && ! "$4" =~ ^[YyNn]$ ]]; then
            echo "Error: Choice must be 'y' or 'n'." >&2
            exit 1
        fi
        add_task "$2" "$3" "$4"
        exit 0
        ;;
    delete)
        if [[ -z "$2" ]]; then
            echo "Error: Task number (argument 2) is required." >&2
            exit 1
        fi
        if ! [[ "$2" =~ ^[0-9]+$ ]] || [[ "$2" -eq 0 ]]; then
            echo "Error: Task number must be a positive integer." >&2
            exit 1
        fi
        if ! task_exists "$2"; then
            echo "Error: Task number $2 not found." >&2
            exit 1
        fi
        delete_task "$2"
        exit 0
        ;;
    toggle)
        if [[ -z "$2" ]]; then
            echo "Error: Task number (argument 2) is required." >&2
            exit 1
        fi
        if ! [[ "$2" =~ ^[0-9]+$ ]] || [[ "$2" -eq 0 ]]; then
            echo "Error: Task number must be a positive integer." >&2
            exit 1
        fi
        if ! task_exists "$2"; then
            echo "Error: Task number $2 not found." >&2
            exit 1
        fi
        toggle_status "$2"
        exit 0
        ;;
    edit)
        if [[ -z "$2" ]]; then
            echo "Error: Task number (argument 2) is required." >&2
            exit 1
        fi
        if ! [[ "$2" =~ ^[0-9]+$ ]] || [[ "$2" -eq 0 ]]; then
            echo "Error: Task number must be a positive integer." >&2
            exit 1
        fi
        if ! task_exists "$2"; then
            echo "Error: Task number $2 not found." >&2
            exit 1
        fi
        if [[ -z "$3" ]]; then
            echo "Error: New priority (argument 3) is required." >&2
            exit 1
        fi
        if ! [[ "$3" =~ ^[0-9]+$ ]]; then
            echo "Error: Priority must be a number." >&2
            exit 1
        fi
        if [[ -z "$4" ]]; then
            echo "Error: New description (argument 4) is required." >&2
            exit 1
        fi
        if [[ -z "$5" ]]; then
            echo "Error: Current status (argument 5) is required (0 for pending, 1 for completed)." >&2
            exit 1
        fi
        if [[ "$5" != "0" && "$5" != "1" ]]; then
            echo "Error: Current status must be 0 or 1." >&2
            exit 1
        fi
        edit_task "$2" "$3" "$4" "$5"
        exit 0
        ;;
    delete-all)
        delete_all_tasks
        exit 0
        ;;
    get-completed|delete-completed)
        delete_completed_tasks
        exit 0
        ;;
    get-highest-priority)
        get_highest_priority_task_index
        exit 0
        ;;
    get-raw)
        get_raw_tasks
        exit 0
        ;;
    *)
        echo "Error: Invalid operation '$1'." >&2
        echo "Available operations: add, delete, toggle, edit, delete-all, delete-completed, get-highest-priority, get-raw" >&2
        exit 1
        ;;
esac

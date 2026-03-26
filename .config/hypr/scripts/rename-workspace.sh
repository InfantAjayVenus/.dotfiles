#!/bin/bash
# Usage: ./swap_workspaces.sh <id1> <id2>

TARGET=$1
ACTIVE=$(hyprctl activeworkspace -j | jq '.id')
TEMP=9999

# 1. Move all windows from WS 1 to a hidden temp workspace (99)
hyprctl clients -j | jq -r --argjson TARGET "$TARGET" '.[] | select(.workspace.id == $TARGET) | .address' | xargs -I {} hyprctl dispatch movetoworkspacesilent $TEMP,address:{}

# 2. Move all windows from WS 2 to WS 1
hyprctl clients -j | jq -r --argjson ACTIVE "$ACTIVE" '.[] | select(.workspace.id == $ACTIVE) | .address' | xargs -I {} hyprctl dispatch movetoworkspacesilent $TARGET,address:{}

# 3. Move all windows from temp (99) back to WS 2
hyprctl clients -j | jq -r --argjson TEMP "$TEMP" '.[] | select(.workspace.id == $TEMP) | .address' | xargs -I {} hyprctl dispatch movetoworkspacesilent $ACTIVE,address:{}

# --- NEW: Set Focus to the first window on the Target Workspace ---
# We use 'head -n 1' to grab just the first window's address
FIRST_WINDOW=$(hyprctl clients -j | jq -r --argjson T "$TARGET" '.[] | select(.workspace.id == $T) | .address' | head -n 1)

if [ -n "$FIRST_WINDOW" ]; then
  hyprctl dispatch focuswindow address:"$FIRST_WINDOW"
fi

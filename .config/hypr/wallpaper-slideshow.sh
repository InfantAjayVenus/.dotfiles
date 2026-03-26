#!/bin/bash

# This script is for changing wallpaper every minute.
# It assumes hyprpaper is already running and configured for IPC.

while true; do
  wallpaper=$(fd ".png|.jpg|.jpeg|.webp" ~/wallpaper/ | shuf -n1)
  
  if [ -z "$wallpaper" ]; then
    echo "$(date): No wallpapers found in ~/wallpaper/. Retrying in 1 minute."
    sleep 60
    continue
  fi

  echo "$(date): Changing wallpaper to $wallpaper"
  hyprctl hyprpaper preload "$wallpaper"
  hyprctl hyprpaper wallpaper ",$wallpaper"

  sleep 60
done

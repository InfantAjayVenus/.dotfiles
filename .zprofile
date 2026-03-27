# Only autostart Hyprland on login to tty1
if [[ -z $DISPLAY && $(tty) == /dev/tty1 ]]; then
  exec start-hyprland
fi

#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

# if [ -z "$DISPLAY" ] && ["$(tty)" = "/dev/tty1" ]; then
#   exec Hyprland
# fi

## [Completion]
## Completion scripts setup. Remove the following line to uninstall
[ -f /home/ajay/.dart-cli-completion/bash-config.bash ] && . /home/ajay/.dart-cli-completion/bash-config.bash || true
## [/Completion]

# Only autostart Hyprland on login to tty1
if [[ -z $DISPLAY && $(tty) == /dev/tty1 ]]; then
  exec start-hyprland
fi

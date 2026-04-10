A simple waybar, with pomodoro timer and todo widget.

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/31208bdd-23fc-4d92-bf94-75e92d9df29d" />
<br><br>
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/9b368093-19f6-4149-8ac6-4daac6a8dd3e" />

<br>

## Dependencies

Pomodoro timer is implemented locally in `~/.config/waybar/scripts/pomodoro.py` and only requires:
- `python3`
- `notify-send`

Required Fonts:
'SF Pro Text', 'Inter', 'Segoe UI', 'NotoSans Nerd Font', 'sans-serif'

For arch:
```
sudo pacman -S inter-font
sudo pacman -S ttf-noto-nerd
yay -S apple-fonts
yay -S ttf-ms-win11-segoe-ui-variable
```

Refresh cache:
```
fc-cache -fv
```
[windows wallpaper](https://raw.githubusercontent.com/Prateek7071/dotfiles/main/asset/3.jpg)<br>

## Modules

**Left:** CPU monitoring (opens htop on click), Workspaces <br>
**Centre:** Clock with day and date (IST) <br>
**Right:** Todo (right-click opens TUI with compact commands like `e3`, `d2`, `t1`, double-click marks done), Pomodoro timer (click to toggle, right-click to reset), Bluetooth (opens `bluetui` in a floating Kitty window on click), Wifi (opens `wlctl` in a floating Kitty window on click), Volume/PulseAudio (opens pavucontrol on click), Brightness, Battery, Power drawer (Shutdown / Reboot / Logout)

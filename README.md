# Dotfiles Replication Guide

Replicate the full Hyprland setup (keybindings, waybar, scripts, packages) to a new system using a **bare git repository**.

A bare git repo stores only git internals (no working tree). By pointing its `--work-tree` at `$HOME`, files are tracked in-place — no copies or symlinks needed.

---

## On the Source System

### 1. Initialize the bare repo

```bash
git init --bare $HOME/.dotfiles
alias dotfiles='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
dotfiles config --local status.showUntrackedFiles no
```

Add the alias permanently:

```bash
echo "alias dotfiles='git --git-dir=\$HOME/.dotfiles/ --work-tree=\$HOME'" >> ~/.bashrc
```

### 2. Track your configs

```bash
# Hyprland
dotfiles add ~/.config/hypr/hyprland.conf
dotfiles add ~/.config/hypr/hypridle.conf
dotfiles add ~/.config/hypr/hyprlock.conf
dotfiles add ~/.config/hypr/hyprpaper.conf
dotfiles add ~/.config/hypr/scripts/
dotfiles add ~/.config/hypr/wallpaper-slideshow.sh

# Waybar
dotfiles add ~/.config/waybar/
dotfiles add ~/.config/wlogout/

# Terminal & UI
dotfiles add ~/.config/kitty/kitty.conf
dotfiles add ~/.config/rofi/config.rasi
dotfiles add ~/.config/dunst/dunstrc
dotfiles add ~/.config/swaylock/config
dotfiles add ~/.config/Kvantum/kvantum.kvconfig
dotfiles add ~/.config/qt5ct/qt5ct.conf
dotfiles add ~/.config/qt6ct/qt6ct.conf

# Other tools
dotfiles add ~/.config/btop/btop.conf
dotfiles add ~/.config/lazygit/config.yml
dotfiles add ~/.config/workstyle/config.toml

# Shell
dotfiles add ~/.bashrc ~/.bash_profile ~/.zshrc ~/.zprofile
```

### 3. Save package lists

```bash
pacman -Qqe  > ~/.config/pkglist.txt      # all explicitly installed packages
pacman -Qqem > ~/.config/pkglist-aur.txt  # AUR/foreign packages only

dotfiles add ~/.config/pkglist.txt ~/.config/pkglist-aur.txt
```

### 4. Commit and push

```bash
dotfiles commit -m "Initial dotfiles: hyprland, waybar, kitty, rofi, etc."
dotfiles remote add origin https://github.com/YOUR_USERNAME/dotfiles.git
dotfiles push -u origin main
```

---

## On the New System

### 1. Clone the bare repo

```bash
git clone --bare https://github.com/YOUR_USERNAME/dotfiles.git $HOME/.dotfiles
alias dotfiles='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
```

### 2. Checkout files (backup conflicts first)

```bash
dotfiles checkout 2>&1 \
  | grep -E "\s+\." \
  | awk '{print $1}' \
  | xargs -I{} bash -c 'mkdir -p .config-backup/$(dirname {}) && mv {} .config-backup/{}'

dotfiles checkout
dotfiles config --local status.showUntrackedFiles no
```

### 3. Reinstall packages

```bash
# Official packages
sudo pacman -S --needed - < ~/.config/pkglist.txt

# AUR packages (requires yay installed first)
yay -S --needed - < ~/.config/pkglist-aur.txt
```

### 4. Build the Waybar Pomodoro module

The pomodoro timer is bundled as Rust source (no pre-built binary is tracked). Build it once after checkout:

```bash
cd ~/.config/waybar/scripts/waybar-module-pomodoro
cargo build --release
```

The shell configs (`.bashrc` / `.zshrc`) already add `target/release` to `$PATH`, so no manual install is needed — the binary is available immediately after the build.

---

## What Gets Replicated

| Component                     | Source                                      |
|-------------------------------|---------------------------------------------|
| Hyprland keybindings & config | `hypr/hyprland.conf`                        |
| Idle & lock screen            | `hypr/hypridle.conf`, `hyprlock.conf`        |
| Wallpaper                     | `hypr/hyprpaper.conf`                       |
| Waybar layout & styling       | `waybar/config.jsonc`, `style.css`, `scripts/`|
| Pomodoro timer (source)       | `waybar/scripts/waybar-module-pomodoro/`    |
| Hyprland scripts              | `hypr/scripts/`, `wallpaper-slideshow.sh`   |
| Keyboard input config         | input section in `hyprland.conf`            |
| Terminal (kitty)              | `kitty/kitty.conf`                          |
| App launcher (rofi)           | `rofi/config.rasi`                          |
| Notifications (dunst)         | `dunst/dunstrc`                             |
| Lock screen (swaylock)        | `swaylock/config`                           |
| Qt theme (Kvantum)            | `Kvantum/kvantum.kvconfig`                  |
| Qt5/Qt6 settings              | `qt5ct/qt5ct.conf`, `qt6ct/qt6ct.conf`      |
| System monitor (btop)         | `btop/btop.conf`                            |
| Git UI (lazygit)              | `lazygit/config.yml`                        |
| Workspace manager (workstyle) | `workstyle/config.toml`                     |
| Logout screen (wlogout)       | `wlogout/`                                  |
| Shell config                  | `.bashrc`, `.bash_profile`, `.zshrc`, `.zprofile` |
| All packages (official + AUR) | `pkglist.txt`, `pkglist-aur.txt`            |

---

## Day-to-day Usage

```bash
dotfiles status                        # see what changed
dotfiles add ~/.config/hypr/hyprland.conf
dotfiles commit -m "update keybinds"
dotfiles push
```

On the other machine:

```bash
dotfiles pull
```

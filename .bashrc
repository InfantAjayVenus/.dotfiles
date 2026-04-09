if command -v zoxide &>/dev/null; then
  eval "$(zoxide init bash)"
fi

if command -v zoxide &>/dev/null; then
  alias cd="zd"
  zd() {
    if [ $# -eq 0 ]; then
      builtin cd ~ && return
    elif [ -d "$1" ]; then
      builtin cd "$1"
    else
      z "$@" && printf "\U000F17A9 " && pwd || echo "Error: Directory not found"
    fi
  }
fi

eval "$(starship init bash)"

export STARSHIP_CONFIG="~/.config/starship.toml"
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export MANDA_DIR=~/DevSpace/brain-dump
alias lg="lazygit"
alias vim=nvim
export EDITOR=nvim
export PATH="$PATH:$HOME/.local/bin"
export PATH="$PATH:$HOME/flutter/bin"
export PATH="$PATH:$HOME/.cargo/bin"
export PATH="$PATH:$HOME/.npm-global/bin"
export PATH="$PATH:$HOME/.config/waybar/scripts/waybar-module-pomodoro/target/release"

export ANDROID_HOME="/home/ajay/Android/Sdk/"
export CHROME_EXECUTABLE="/usr/bin/helium-browser"
alias dotfiles='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
alias dlg="lazygit --git-dir=$HOME/.dotfiles --work-tree=$HOME"

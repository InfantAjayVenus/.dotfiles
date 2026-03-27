source /usr/share/cachyos-zsh-config/cachyos-config.zsh

# --- Environment Variables ---
export STARSHIP_CONFIG="~/.config/starship.toml"
export MANDA_DIR=~/DevSpace/brain-dump
export EDITOR=nvim
export ANDROID_HOME="/home/ajay/Android/Sdk/"
export CHROME_EXECUTABLE="/usr/bin/helium-browser"

# --- PATH ---
export PATH="$PATH:$HOME/.local/bin"
export PATH="$PATH:$HOME/flutter/bin"
export PATH="$PATH:$HOME/.cargo/bin"
export PATH="$PATH:$HOME/.npm-global/bin"

# --- Aliases ---
alias lg="lazygit"
alias vim=nvim
alias dotfiles='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'

# --- zoxide (smart cd) ---
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
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

# --- Starship prompt (overrides powerlevel10k from cachyos-config) ---
eval "$(starship init zsh)"

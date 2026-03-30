# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source /usr/share/cachyos-zsh-config/cachyos-config.zsh

# --- Locale ---
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

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
alias dlg="lazygit --git-dir=$HOME/.dotfiles --work-tree=$HOME"

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

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

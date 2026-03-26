# Oh My Zsh
ZSH=/usr/share/oh-my-zsh/
ZSH_THEME="ys"
plugins=(git)
ZSH_CACHE_DIR=$HOME/.cache/oh-my-zsh
if [[ ! -d $ZSH_CACHE_DIR ]]; then
  mkdir $ZSH_CACHE_DIR
fi
source $ZSH/oh-my-zsh.sh
source /usr/share/zsh/plugins/fzf-tab-git/fzf-tab.plugin.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# bun
export PATH="$HOME/.bun/bin:$PATH"

# mise
if command -v mise &> /dev/null; then
    eval "$(mise activate zsh)"
fi

# zoxide
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi

# Aliases
alias cd="z"
alias cdi="zi"
alias rm="trash-put"

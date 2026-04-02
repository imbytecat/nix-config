# PATH
export PATH="$HOME/go/bin:$PATH"
export PATH="$HOME/.bun/bin:$PATH"

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
alias ls="eza"
alias tree="eza --tree"
alias cat="bat --paging=never"
alias rm="trash-put"

# Local
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

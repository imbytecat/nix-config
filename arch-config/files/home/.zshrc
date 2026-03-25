# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# mise
if command -v mise &> /dev/null; then
    eval "$(mise activate zsh)"
fi

# zoxide
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi

# Aliases
alias ls='ls --color=auto'
alias ll='ls -lah'
alias cd='z'

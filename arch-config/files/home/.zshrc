# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# mise
eval "$(mise activate zsh)"

# zoxide
eval "$(zoxide init zsh)"

# Aliases
alias ls='ls --color=auto'
alias ll='ls -lah'
alias cd='z'

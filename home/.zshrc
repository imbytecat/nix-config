# ── PATH ──
export PATH="$HOME/go/bin:$HOME/.bun/bin:$PATH"

# ── Shell 选项 ──
setopt AUTO_CD              # 输目录名直接 cd
setopt INTERACTIVE_COMMENTS # 允许交互式 # 注释
setopt NO_BEEP              # 关蜂鸣

# ── Oh My Zsh ──
ZSH=/usr/share/oh-my-zsh/
ZSH_THEME=""                # Starship 接管提示符
plugins=(
    git                     # git 别名（gst, gco, gp...）
    sudo                    # 双击 ESC 自动加 sudo
    extract                 # x file.tar.gz 一键解压任何格式
    direnv                  # direnv hook
)
ZSH_CACHE_DIR=$HOME/.cache/oh-my-zsh
[[ ! -d $ZSH_CACHE_DIR ]] && mkdir -p $ZSH_CACHE_DIR
source $ZSH/oh-my-zsh.sh

# ── 外部插件 ──
source /usr/share/zsh/plugins/fzf-tab-git/fzf-tab.plugin.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh  # 必须最后

# ── 工具初始化（顺序重要）──
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$(mise activate zsh)"
eval "$(fzf --zsh)"         # Ctrl+T 搜文件, Alt+C 搜目录
eval "$(atuin init zsh)"    # 必须在 fzf 之后，接管 Ctrl+R

# ── 别名 ──
# 导航
alias cd="z"
alias cdi="zi"
alias ..="cd .."
alias ...="cd ../.."

# 文件列表
alias ls="eza --icons --group-directories-first"
alias ll="eza -la --icons --git --group-directories-first"
alias la="eza -a --icons --group-directories-first"
alias lt="eza --tree --level=2 --icons"

# 工具
alias cat="bat --paging=never"
alias rm="trash-put"
alias lg="lazygit"
alias vi="nvim"

# 网络
alias http="xh"

# ── WSL 剪贴板 ──
if [[ -n "$WSL_DISTRO_NAME" ]]; then
    alias pbcopy="clip.exe"
    alias pbpaste="powershell.exe -noprofile -c Get-Clipboard"
fi

# ── Local ──
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

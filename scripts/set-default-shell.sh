#!/bin/bash
set -euo pipefail

if [ "$SHELL" != "$(which zsh)" ]; then
    echo "==> 设置默认 shell 为 zsh..."
    sudo chsh -s "$(which zsh)" "$USER"
    echo "✓ 默认 shell 已设置为 zsh（重新登录后生效）"
else
    echo "默认 shell 已经是 zsh"
fi

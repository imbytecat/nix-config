#!/bin/bash
set -euo pipefail

REPO_URL="https://git.furtherverse.com/imbytecat/archlinux-config.git"
CONFIG_DIR="$HOME/.config/archlinux-config"

echo "==> 安装 git..."
sudo pacman -S --needed --noconfirm git

echo "==> 克隆配置仓库..."
if [ -d "$CONFIG_DIR/.git" ]; then
    echo "配置仓库已存在：$CONFIG_DIR，跳过克隆"
elif [ -e "$CONFIG_DIR" ]; then
    echo "目标路径已存在且不是 git 仓库：$CONFIG_DIR"
    exit 1
else
    git clone "$REPO_URL" "$CONFIG_DIR"
fi

echo "==> 更新系统..."
sudo pacman -Syu --noconfirm

echo "==> 安装 base-devel..."
sudo pacman -S --needed --noconfirm base-devel

echo "==> 安装 yay-bin..."
if ! command -v yay &> /dev/null; then
    rm -rf /tmp/yay-bin
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    (cd /tmp/yay-bin && makepkg -si --noconfirm)
    rm -rf /tmp/yay-bin
fi

echo "==> 安装 decman..."
yay -S --needed --noconfirm decman

echo "==> 应用系统配置..."
sudo decman --source "$CONFIG_DIR/source.py" < /dev/tty

echo ""
echo "✓ 安装完成！重新登录以使用 zsh。"
echo ""
echo "后续更新配置："
echo "  cd $CONFIG_DIR && git pull && sudo decman"

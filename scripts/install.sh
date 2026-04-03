#!/bin/bash
set -euo pipefail

REPO_URL="https://git.furtherverse.com/imbytecat/archlinux-config.git"
CONFIG_DIR="$HOME/.config/archlinux-config"

echo "==> 验证 sudo 权限..."
sudo -v < /dev/tty || { echo "错误：需要 sudo 权限，请确认当前用户已配置 sudo"; exit 1; }

echo "==> 更新系统..."
sudo pacman -Syu --noconfirm

echo "==> 安装基础依赖..."
sudo pacman -S --needed --noconfirm git base-devel

echo "==> 克隆配置仓库..."
mkdir -p "$(dirname "$CONFIG_DIR")"
if [[ -d "$CONFIG_DIR/.git" ]]; then
    echo "配置仓库已存在：$CONFIG_DIR，跳过克隆"
elif [[ -e "$CONFIG_DIR" ]]; then
    echo "目标路径已存在且不是 git 仓库：$CONFIG_DIR"
    exit 1
else
    git clone "$REPO_URL" "$CONFIG_DIR"
fi

echo "==> 安装 decman..."
if ! command -v decman &> /dev/null; then
    rm -rf /tmp/decman
    git clone https://aur.archlinux.org/decman.git /tmp/decman
    (cd /tmp/decman && makepkg -si --noconfirm)
    rm -rf /tmp/decman
fi

echo "==> 应用系统配置..."
sudo decman --source "$CONFIG_DIR/source.py" < /dev/tty

echo ""
echo "✓ 安装完成！重新登录以使用 zsh。"
echo ""
echo "后续更新配置："
echo "  cd $CONFIG_DIR && git pull && sudo decman"

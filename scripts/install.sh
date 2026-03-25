#!/bin/bash
set -euo pipefail

REPO_URL="https://git.furtherverse.com/imbytecat/archlinux-config.git"
CONFIG_DIR="$HOME/.config/arch-config"

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

echo "==> 配置系统文件..."
sudo cp "$CONFIG_DIR/files/etc/pacman.d/mirrorlist" /etc/pacman.d/mirrorlist
sudo cp "$CONFIG_DIR/files/etc/sudoers.d/10-wheel" /etc/sudoers.d/10-wheel
sudo chmod 440 /etc/sudoers.d/10-wheel

echo "==> 配置 locale..."
sudo sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
sudo locale-gen
echo "LANG=en_US.UTF-8" | sudo tee /etc/locale.conf > /dev/null

echo "==> 更新系统..."
sudo pacman -Syu --noconfirm

echo "==> 安装基础工具..."
sudo pacman -S --needed --noconfirm base-devel

echo "==> 安装 yay..."
if ! command -v yay &> /dev/null; then
    rm -rf /tmp/yay
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
fi

echo "==> 安装 dcli..."
yay -S --needed --noconfirm dcli-arch-git

echo ""
echo "✓ 安装完成！"
echo ""
echo "下一步：运行 dcli sync 应用配置"

#!/bin/bash
set -e

echo "==> 安装 yay (唯一手动步骤)..."
if ! command -v yay &> /dev/null; then
    sudo pacman -S --needed --noconfirm base-devel git
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ~
fi

echo "==> 安装 dcli..."
yay -S --needed --noconfirm dcli-arch-git

echo "==> 初始化 dcli 配置..."
mkdir -p ~/.config/arch-config
cp -r ./arch-config/* ~/.config/arch-config/

echo "==> 运行 dcli sync..."
dcli sync

echo "✓ 完成！所有配置已应用"

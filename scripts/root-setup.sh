#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "请以 root 身份运行此脚本"
    exit 1
fi

USERNAME="${1:-}"
if [ -z "$USERNAME" ]; then
    echo "用法: ./root-setup.sh <用户名>"
    echo "示例: ./root-setup.sh imbytecat"
    exit 1
fi

echo "==> 安装 sudo..."
pacman -Syu --noconfirm sudo

echo "==> 创建用户 $USERNAME..."
if id "$USERNAME" &> /dev/null; then
    echo "用户 $USERNAME 已存在，跳过创建"
else
    useradd -m -G wheel -s /bin/bash "$USERNAME"
    echo "请设置 $USERNAME 的密码："
    passwd "$USERNAME" < /dev/tty
fi

echo "==> 配置 WSL 默认用户..."
cat > /etc/wsl.conf << EOF
[user]
default = $USERNAME
EOF

echo ""
echo "✓ 初始化完成！"
echo ""
echo "下一步："
echo "  1. 在 PowerShell 中执行: wsl --terminate archlinux"
echo "  2. 重新打开 Arch WSL（将以 $USERNAME 身份登录）"
echo "  3. 运行: curl -fsSL https://git.furtherverse.com/imbytecat/archlinux-config/raw/branch/main/scripts/install.sh | bash"

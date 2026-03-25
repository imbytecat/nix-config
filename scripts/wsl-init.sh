#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "请以 root 身份运行此脚本"
    exit 1
fi

if ! grep -qiE '(microsoft|wsl)' /proc/sys/kernel/osrelease 2>/dev/null; then
    echo "此脚本仅用于 Arch Linux on WSL 的首次初始化"
    exit 1
fi

USERNAME="${1:-}"
if [ -z "$USERNAME" ]; then
    echo "用法: wsl-init.sh <用户名>"
    echo "示例: wsl-init.sh imbytecat"
    exit 1
fi

echo "==> 安装 sudo..."
pacman -S --needed --noconfirm sudo

echo "==> 配置 sudo 权限..."
cat > /etc/sudoers.d/10-wheel << 'EOF'
%wheel ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/10-wheel

echo "==> 创建用户 $USERNAME..."
if id "$USERNAME" &> /dev/null; then
    echo "用户 $USERNAME 已存在，跳过创建"
else
    useradd -m -G wheel -s /bin/bash "$USERNAME"
    echo "请设置 $USERNAME 的密码："
    passwd "$USERNAME" < /dev/tty
fi

echo ""
echo "✓ WSL 初始化完成！"
echo ""
echo "下一步："
echo "  1. 在 PowerShell 中设置默认用户："
echo "     wsl --manage archlinux --set-default-user $USERNAME"
echo "  2. 重启 WSL："
echo "     wsl --terminate archlinux"
echo "  3. 重新打开 Arch WSL 后运行："
echo "     curl -fsSL https://git.furtherverse.com/imbytecat/archlinux-config/raw/branch/main/scripts/install.sh | bash"

"""
Arch Linux 声明式系统配置 — decman

用法：
  首次：sudo decman --source /path/to/source.py
  后续：sudo decman
"""

import os

import decman
from decman import File

assert decman.pacman is not None
assert decman.aur is not None

# ── 用户 ──────────────────────────────────────────────────────
# sudo decman 时 SUDO_USER 为调用 sudo 的原始用户
USERNAME = os.environ.get("SUDO_USER", "imbytecat")
HOME = f"/home/{USERNAME}"

# ── Pacman 包（官方仓库）──────────────────────────────────────
decman.pacman.packages |= {
    "base-devel",
    "bat",
    "curl",
    "fd",
    "fzf",
    "git",
    "neovim",
    "nodejs",
    "ripgrep",
    "sudo",
    "trash-cli",
    "vim",
    "wget",
    "zoxide",
    "zsh-autosuggestions",
    "zsh-completions",
    "zsh-syntax-highlighting",
    "zsh",
}

# ── AUR 包 ────────────────────────────────────────────────────
decman.aur.packages |= {
    "decman",  # 管理自身更新
    # 开发工具
    "bun",
    "mise",
    # Zsh 插件
    "fzf-tab-git",
    "oh-my-zsh-git",
}

# yay 由 bootstrap 脚本安装，decman 不管理其生命周期
decman.aur.ignored_packages |= {"yay"}

# ── 系统文件（/etc/）──────────────────────────────────────────
decman.files["/etc/pacman.d/mirrorlist"] = File(
    source_file="./files/etc/pacman.d/mirrorlist",
)

decman.files["/etc/sudoers.d/10-wheel"] = File(
    source_file="./files/etc/sudoers.d/10-wheel",
    permissions=0o440,
)

decman.files["/etc/locale.conf"] = File(content="LANG=en_US.UTF-8\n")

# 仅保留需要的 locale；修改后需手动执行 locale-gen
decman.files["/etc/locale.gen"] = File(content="en_US.UTF-8 UTF-8\n")

# ── 用户 Dotfiles ────────────────────────────────────────────
decman.files[f"{HOME}/.zshrc"] = File(
    source_file="./dotfiles/.zshrc",
    owner=USERNAME,
)

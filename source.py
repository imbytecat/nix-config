"""
Arch Linux 声明式系统配置 — decman

用法：
  首次：sudo decman --source /path/to/source.py
  后续：sudo decman
"""

import os

import decman
from decman import File

import locale_module

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
    "bun",
    "decman",
    "fzf-tab-git",
    "mise",
    "oh-my-zsh-git",
    "yay",
}

# ── 系统文件（/etc/）──────────────────────────────────────────
decman.files["/etc/pacman.d/mirrorlist"] = File(
    source_file="./system/etc/pacman.d/mirrorlist",
)

decman.files["/etc/sudoers.d/10-wheel"] = File(
    source_file="./system/etc/sudoers.d/10-wheel",
    permissions=0o440,
)

decman.modules += [locale_module.LocaleModule()]

# ── 用户配置 ─────────────────────────────────────────────────
decman.files[f"{HOME}/.zshrc"] = File(
    source_file="./home/.zshrc",
    owner=USERNAME,
)

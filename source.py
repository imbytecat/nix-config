"""
Arch Linux 声明式系统配置 — decman

执行顺序：files → pacman → aur → systemd
用法：
  首次：sudo decman --source /path/to/source.py
  后续：sudo decman
"""

import os

import decman
from decman import File

import docker_module
import locale_module

assert decman.pacman is not None
assert decman.aur is not None
assert decman.systemd is not None

# ── 用户 ──────────────────────────────────────────────────────
USERNAME = os.environ.get("SUDO_USER")
if not USERNAME:
    raise decman.SourceError("请使用 sudo decman 运行")
HOME = f"/home/{USERNAME}"

# ── 系统文件（/etc/）──────────────────────────────────────────
decman.files["/etc/pacman.d/mirrorlist"] = File(
    source_file="./system/etc/pacman.d/mirrorlist",
)

decman.files["/etc/sudoers.d/10-wheel"] = File(
    source_file="./system/etc/sudoers.d/10-wheel",
    permissions=0o440,
)

# ── 用户配置 ─────────────────────────────────────────────────
decman.files[f"{HOME}/.zshrc"] = File(
    source_file="./home/.zshrc",
    owner=USERNAME,
)

# ── Modules ──────────────────────────────────────────────────
decman.modules += [
    locale_module.LocaleModule(),
    docker_module.DockerModule(),
]

# ── Pacman 包（官方仓库）──────────────────────────────────────
decman.pacman.packages |= {
    "base-devel",
    "bat",
    "bun",
    "curl",
    "fd",
    "fzf",
    "git",
    "mise",
    "neovim",
    "nodejs",
    "ripgrep",
    "sudo",
    "trash-cli",
    "vim",
    "wget",
    "zoxide",
    "zsh",
    "zsh-autosuggestions",
    "zsh-completions",
    "zsh-syntax-highlighting",
}

# ── AUR 包 ────────────────────────────────────────────────────
decman.aur.packages |= {
    "decman",
    "fzf-tab-git",
    "oh-my-zsh-git",
    "yay",
}

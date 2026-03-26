"""
Arch Linux 声明式系统配置 — decman

执行顺序：files → pacman → aur → systemd
用法：
  首次：sudo decman --source /path/to/source.py
  后续：sudo decman
"""

import os

import decman

import modules.base
import modules.docker
import modules.locale
import modules.zsh

assert decman.pacman is not None
assert decman.aur is not None
assert decman.systemd is not None

# ── 用户 ──────────────────────────────────────────────────────
USERNAME = os.environ.get("SUDO_USER")
if not USERNAME:
    raise decman.SourceError("请使用 sudo decman 运行")

# ── Modules ──────────────────────────────────────────────────
decman.modules += [
    modules.base.BaseModule(),
    modules.locale.LocaleModule(),
    modules.docker.DockerModule(),
    modules.zsh.ZshModule(USERNAME),
]

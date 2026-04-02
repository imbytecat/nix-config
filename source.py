import os

import decman

import modules.base
import modules.cli
import modules.dev
import modules.docker
import modules.locale
import modules.wsl
import modules.zsh

assert decman.pacman is not None
assert decman.aur is not None
assert decman.systemd is not None

USERNAME = os.environ.get("SUDO_USER")
if not USERNAME:
    raise decman.SourceError("请使用 sudo 运行")

IS_WSL = os.path.exists("/proc/sys/fs/binfmt_misc/WSLInterop")

decman.modules += [
    modules.base.BaseModule(),
    modules.cli.CliModule(USERNAME),
    modules.dev.DevModule(USERNAME),
    modules.docker.DockerModule(USERNAME),
    modules.locale.LocaleModule(),
    modules.zsh.ZshModule(USERNAME),
]

if IS_WSL:
    decman.modules += [modules.wsl.WslModule()]

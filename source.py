import os

import decman

import modules.base
import modules.docker
import modules.locale
import modules.zsh

assert decman.pacman is not None
assert decman.aur is not None
assert decman.systemd is not None

USERNAME = os.environ.get("SUDO_USER")
if not USERNAME:
    raise decman.SourceError("请使用 sudo decman 运行")

decman.modules += [
    modules.base.BaseModule(),
    modules.locale.LocaleModule(),
    modules.docker.DockerModule(),
    modules.zsh.ZshModule(USERNAME),
]

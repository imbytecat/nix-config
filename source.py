import os

import decman

import modules.base
import modules.dev
import modules.docker
import modules.locale
import modules.zsh

if decman.pacman is None or decman.aur is None or decman.systemd is None:
    raise decman.SourceError("缺少必要插件，请检查 decman 安装")

USERNAME = os.environ.get("SUDO_USER")
if not USERNAME:
    raise decman.SourceError("请使用 sudo 运行")

decman.modules += [
    modules.base.BaseModule(USERNAME),
    modules.dev.DevModule(USERNAME),
    modules.docker.DockerModule(USERNAME),
    modules.locale.LocaleModule(),
    modules.zsh.ZshModule(USERNAME),
]

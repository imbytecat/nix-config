import decman
from decman import File, Module


class LocaleModule(Module):
    def __init__(self):
        super().__init__("locale")

    def files(self):
        return {
            "/etc/locale.conf": File(content="LANG=en_US.UTF-8\n"),
            "/etc/locale.gen": File(content="en_US.UTF-8 UTF-8\n"),
        }

    def on_change(self, store):
        decman.prg(["locale-gen"])

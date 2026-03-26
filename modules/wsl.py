import decman
from decman import Module


class WslModule(Module):
    def __init__(self):
        super().__init__("wsl")

    def on_enable(self, store):
        decman.prg(["systemctl", "mask", "systemd-networkd-wait-online.service"])

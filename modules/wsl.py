import subprocess

import decman
from decman import Module


class WslModule(Module):
    def __init__(self):
        super().__init__("wsl")

    def after_update(self, store):
        try:
            result = subprocess.run(
                ["systemctl", "is-enabled", "systemd-networkd-wait-online.service"],
                capture_output=True,
                text=True,
            )
            if result.stdout.strip() != "masked":
                decman.prg(
                    ["systemctl", "mask", "systemd-networkd-wait-online.service"]
                )
        except Exception:
            print(
                "警告：systemd 不可用，跳过 mask systemd-networkd-wait-online.service"
            )

from decman import File, Module
from decman.plugins.aur import packages as aur_packages
from decman.plugins.pacman import packages as pacman_packages


class BaseModule(Module):
    def __init__(self):
        super().__init__("base")

    def files(self):
        return {
            "/etc/pacman.d/mirrorlist": File(
                source_file="./system/etc/pacman.d/mirrorlist",
            ),
            "/etc/sudoers.d/10-wheel": File(
                source_file="./system/etc/sudoers.d/10-wheel",
                permissions=0o440,
            ),
        }

    @pacman_packages
    def pacman_packages(self) -> set[str]:
        return {
            "base-devel",
            "curl",
            "git",
            "sudo",
            "vim",
            "wget",
        }

    @aur_packages
    def aur_packages(self) -> set[str]:
        return {
            "decman",
            "yay-bin",
        }

from decman import File, Module
from decman.plugins.pacman import packages as pacman_packages


class CliModule(Module):
    def __init__(self, user: str):
        super().__init__("cli")
        self.user = user

    def files(self):
        return {
            f"/home/{self.user}/.config/git/config": File(
                source_file="./home/.config/git/config",
                owner=self.user,
            ),
            f"/home/{self.user}/.config/mise/config.toml": File(
                source_file="./home/.config/mise/config.toml",
                owner=self.user,
            ),
        }

    @pacman_packages
    def pacman_packages(self) -> set[str]:
        return {
            "bat",
            "btop",
            "duf",
            "dust",
            "eza",
            "fastfetch",
            "fd",
            "git-delta",
            "jq",
            "micro",
            "procs",
            "ripgrep",
            "tealdeer",
            "trash-cli",
            "yazi",
            "zoxide",
        }

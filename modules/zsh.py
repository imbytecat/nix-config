import decman
from decman import File, Module
from decman.plugins.aur import packages as aur_packages
from decman.plugins.pacman import packages as pacman_packages


class ZshModule(Module):
    def __init__(self, user: str):
        super().__init__("zsh")
        self.user = user

    def files(self):
        return {
            f"/home/{self.user}/.zshrc": File(
                source_file="./home/.zshrc",
                owner=self.user,
            ),
        }

    @pacman_packages
    def pacman_packages(self) -> set[str]:
        return {
            "fzf",
            "zsh",
            "zsh-autosuggestions",
            "zsh-completions",
            "zsh-syntax-highlighting",
        }

    @aur_packages
    def aur_packages(self) -> set[str]:
        return {
            "fzf-tab-git",
            "oh-my-zsh-git",
        }

    def on_enable(self, store):
        decman.prg(["chsh", "-s", "/usr/bin/zsh", self.user])

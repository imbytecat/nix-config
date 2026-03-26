import decman
from decman import Module
from decman.plugins.pacman import packages as pacman_packages

BUN_GLOBAL_PACKAGES = [
    "@mariozechner/pi-coding-agent",
    "opencode-ai",
]

GO_INSTALL_PACKAGES = [
    "github.com/code-yeongyu/go-claude-code-comment-checker/cmd/comment-checker@latest",
]


class DevModule(Module):
    def __init__(self, user: str):
        super().__init__("dev")
        self.user = user

    @pacman_packages
    def pacman_packages(self) -> set[str]:
        return {
            "bat",
            "biome",
            "btop",
            "bun",
            "eza",
            "fastfetch",
            "fd",
            "go",
            "lazygit",
            "micro",
            "mise",
            "neovim",
            "nodejs",
            "ripgrep",
            "trash-cli",
            "uv",
            "yaml-language-server",
            "zoxide",
        }

    def on_change(self, store):
        for pkg in BUN_GLOBAL_PACKAGES:
            decman.prg(["su", "-", self.user, "-c", f"bun add -g {pkg}"])
        for pkg in GO_INSTALL_PACKAGES:
            decman.prg(["su", "-", self.user, "-c", f"go install {pkg}"])

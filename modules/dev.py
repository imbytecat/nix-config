import decman
from decman import File, Module
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

    def files(self):
        return {
            f"/home/{self.user}/.config/mise/config.toml": File(
                source_file="./home/.config/mise/config.toml",
                owner=self.user,
            ),
        }

    @pacman_packages
    def pacman_packages(self) -> set[str]:
        return {
            "ast-grep",
            "biome",
            "bun",
            "github-cli",
            "go",
            "lazygit",
            "mise",
            "neovim",
            "nodejs",
            "tmux",
            "uv",
            "yaml-language-server",
        }

    def after_update(self, store):
        for pkg in BUN_GLOBAL_PACKAGES:
            try:
                decman.prg(["su", "-", self.user, "-c", f"bun add -g {pkg}"])
            except Exception:
                print(f"警告：安装 {pkg} 失败，跳过")
        for pkg in GO_INSTALL_PACKAGES:
            try:
                decman.prg(["su", "-", self.user, "-c", f"go install {pkg}"])
            except Exception:
                print(f"警告：安装 {pkg} 失败，跳过")

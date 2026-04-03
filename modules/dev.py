import decman
from decman import File, Module
from decman.plugins.pacman import packages as pacman_packages

BUN_GLOBAL_PACKAGES = [
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
            "bash-language-server",
            "biome",
            "bun",
            "github-cli",
            "go",
            "lazygit",
            "mise",
            "neovim",
            "nodejs",
            "shellcheck",
            "shfmt",
            "tmux",
            "uv",
            "yaml-language-server",
            "zellij",
        }

    def after_update(self, store):
        failures: list[str] = []
        for pkg in BUN_GLOBAL_PACKAGES:
            try:
                decman.prg(["bun", "add", "-g", pkg], user=self.user, mimic_login=True)
            except Exception as e:
                failures.append(f"bun: {pkg} ({e})")
        for pkg in GO_INSTALL_PACKAGES:
            try:
                decman.prg(["go", "install", pkg], user=self.user, mimic_login=True)
            except Exception as e:
                failures.append(f"go: {pkg} ({e})")
        if failures:
            print(f"\n⚠ {len(failures)} 个全局包安装失败：")
            for f in failures:
                print(f"  - {f}")
            print()

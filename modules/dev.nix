{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # ── 语言运行时 ──
    bun
    go
    nodejs

    # ── 包管理 / 版本管理 ──
    mise
    uv

    # ── 编辑器 ──
    neovim

    # ── 终端复用 ──
    tmux
    zellij

    # ── Git 增强 ──
    delta # Arch 包名: git-delta
    gh # Arch 包名: github-cli
    lazygit

    # ── Linter / Formatter ──
    biome
    ruff
    shellcheck
    shfmt

    # ── LSP 服务器 ──
    ast-grep
    bash-language-server
    gopls
    typescript-language-server # 若报错尝试 nodePackages.typescript-language-server
    yaml-language-server # 若报错尝试 nodePackages.yaml-language-server
    vue-language-server # 替代原 bun -g @vue/language-server
    dockerfile-language-server-nodejs # 替代原 bun -g dockerfile-language-server

    # ── 原 bun/go 全局安装的工具 ──
    # 以下工具如果在 nixpkgs 中不存在，需要自定义打包：
    #
    # opencode-ai:
    #   buildNpmPackage { pname = "opencode-ai"; ... }
    #
    # go-claude-code-comment-checker:
    #   buildGoModule {
    #     pname = "comment-checker";
    #     src = fetchFromGitHub { owner = "code-yeongyu"; repo = "..."; ... };
    #     vendorHash = "sha256-...";
    #   }
  ];
}

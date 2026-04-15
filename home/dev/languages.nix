{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # ── 语言运行时 ──
    nodejs
    go
    bun
    python3

    # ── 包管理 / 版本管理 ──
    uv

    # ── LSP 服务器 ──
    bash-language-server
    gopls
    typescript-language-server
    yaml-language-server
    vue-language-server
    dockerfile-language-server
    lua-language-server
    nixd
    just-lsp

    # ── 代码检查 / 格式化 ──
    biome
    ruff
    shellcheck
    shfmt
    nixfmt
    statix
    stylua

    # ── 代码智能 ──
    ast-grep
  ];

  # ── mise ─────────────────────────────────────────────
  programs.mise = {
    enable = true;
    enableFishIntegration = true;
    globalConfig = {
      settings = {
        trusted_config_paths = [ "/" ];
        all_compile = false;
      };
    };
  };
}

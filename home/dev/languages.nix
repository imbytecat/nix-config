{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # ── Language runtimes ──
    nodejs
    go
    bun

    # ── Package management / version management ──
    uv

    # ── LSP servers ──
    bash-language-server
    gopls
    typescript-language-server
    yaml-language-server
    vue-language-server
    dockerfile-language-server
    lua-language-server
    nixd
    just-lsp

    # ── Linter / Formatter ──
    biome
    ruff
    shellcheck
    shfmt
    nixfmt
    statix
    stylua

    # ── Code intelligence ──
    ast-grep
  ];

  # ── mise ─────────────────────────────────────────────
  programs.mise = {
    enable = true;
    enableFishIntegration = true;
    globalConfig = {
      settings = {
        trusted_config_paths = [ "/" ];
      };
    };
  };
}

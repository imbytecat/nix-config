{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # ── Language runtimes ──
    # Node.js: 默认跟随 nixpkgs，当前 unstable 为 v24.14.0
    # 如需固定 LTS 版本，改为: nodejs_22 或 nodejs_20
    nodejs
    go
    bun

    # ── Package management / version management ──
    mise
    uv

    # ── LSP servers ──
    bash-language-server
    gopls
    typescript-language-server
    yaml-language-server
    vue-language-server
    dockerfile-language-server-nodejs
    lua-language-server
    nil # Nix LSP

    # ── Linter / Formatter ──
    biome
    ruff
    shellcheck
    shfmt
    nixfmt-rfc-style # nix formatter
    stylua

    # ── Code intelligence ──
    ast-grep
  ];

  # ── mise config ──────────────────────────────────────
  xdg.configFile."mise/config.toml".text = ''
    [settings]
    trusted_config_paths = ["/"]
  '';
}

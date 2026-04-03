{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # ── Language runtimes ──
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

{ pkgs, ... }:

{
  home.packages = with pkgs; [
    bun
    go
    nodejs
    python3

    uv

    fvm
    proto
    android-tools

    bash-language-server
    dockerfile-language-server
    gopls
    just-lsp
    lua-language-server
    nixd
    typescript-language-server
    # vue-language-server  # 依赖 insecure pnpm，不常用先注释
    yaml-language-server

    biome
    nixfmt
    ruff
    shellcheck
    shfmt
    statix
    stylua

    ast-grep
  ];

  programs.fish.interactiveShellInit = ''
    proto activate fish --no-shim | source
  '';
}

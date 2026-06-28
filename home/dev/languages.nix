{ pkgs, ... }:

{
  home.packages = with pkgs; [
    bun
    go
    nodejs
    python3

    uv

    proto

    bash-language-server
    dockerfile-language-server
    gopls
    just-lsp
    lua-language-server
    nixd
    typescript-language-server
    vue-language-server
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

{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    bun
    go
    nodejs
    python3

    uv

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

  programs.mise = {
    enable = true;
    globalConfig = {
      settings = {
        trusted_config_paths = [
          "${config.home.homeDirectory}/Developer"
          "${config.home.homeDirectory}/nix-config"
        ];
        all_compile = false;
      };
    };
  };
}

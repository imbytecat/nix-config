{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nodejs
    go
    bun
    python3

    uv

    bash-language-server
    gopls
    typescript-language-server
    yaml-language-server
    vue-language-server
    dockerfile-language-server
    lua-language-server
    nixd
    just-lsp

    biome
    ruff
    shellcheck
    shfmt
    nixfmt
    statix
    stylua

    ast-grep
  ];

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

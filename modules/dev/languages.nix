{
  aspects.homeManager.daily =
    { pkgs, ... }:

    {
      home.packages = with pkgs; [
        bun
        go
        nodejs
        python3
        typst

        uv

        fvm
        android-tools

        bash-language-server
        dockerfile-language-server
        gopls
        just-lsp
        nixd
        typescript-language-server
        yaml-language-server

        biome
        nixfmt
        ruff
        shellcheck
      ];

      programs.mise = {
        enable = true;
        globalConfig.settings = {
          trusted_config_paths = [ "/" ];
          all_compile = false;
        };
      };
    };
}

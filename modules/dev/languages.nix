{
  aspects.homeManager.workstation =
    { config, pkgs, ... }:

    {
      home.packages = with pkgs; [
        bun
        go
        python3

        uv

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

      # 交互 zsh 之外（非交互 shell、SSH、T3 服务）没有 `mise activate`；shims 按 cwd 取项目锁的版本，项目外回落到 Nix 版本。
      home.sessionPath = [ "${config.xdg.dataHome}/mise/shims" ];
    };
}

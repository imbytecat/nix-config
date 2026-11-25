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
      # go install 与 bun add -g 的落点排在 shims 之后。
      home.sessionPath = [
        "${config.xdg.dataHome}/mise/shims"
        "$HOME/go/bin"
        "$HOME/.bun/bin"
      ];
    };
}

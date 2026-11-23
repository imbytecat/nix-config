{
  aspects.homeManager.daily =
    { config, pkgs, ... }:

    {
      home.packages = with pkgs; [
        bun
        go
        nodejs
        python3

        uv

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

      home.sessionVariables.ANDROID_HOME =
        if pkgs.stdenv.hostPlatform.isDarwin then "$HOME/Library/Android/sdk" else "$HOME/Android/Sdk";

      # Android CLI 由项目 mise 安装，遥测默认开启；.androidrc 的全局 flag 对每次调用生效。
      home.file.".androidrc".text = "--no-metrics\n";

      # Flutter 也由项目 mise 安装，遥测默认开启；它自己的开关在工具会改写的 ~/.dart-tool 状态文件里，不能交给 HM。
      home.sessionVariables.FLUTTER_SUPPRESS_ANALYTICS = "true";

      programs.mise = {
        enable = true;
        globalConfig.settings = {
          trusted_config_paths = [ "/" ];
          all_compile = false;
        };
      };

      # 交互 zsh 之外（非交互 shell、SSH、Paseo 服务）没有 `mise activate`；shims 按 cwd 取项目锁的版本，项目外回落到 Nix 版本。
      home.sessionPath = [ "${config.xdg.dataHome}/mise/shims" ];
    };
}

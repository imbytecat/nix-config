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
        android-cli

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

      # Android CLI 遥测默认开启；.androidrc 的全局 flag 对每次调用生效。
      home.file.".androidrc".text = "--no-metrics\n";

      programs.mise = {
        enable = true;
        globalConfig.settings = {
          trusted_config_paths = [ "/" ];
          all_compile = false;
        };
      };
    };
}

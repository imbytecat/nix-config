{
  inputs,
  username,
  pkgs,
  ...
}:

{
  imports = [
    inputs.catppuccin.homeModules.catppuccin
    ./shell
    ./dev
  ];

  catppuccin = {
    enable = true;
    flavor = "mocha";
  };

  home = {
    username = username;
    homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
    stateVersion = "25.11";
  };

  home.packages = with pkgs; [
    # 现代 CLI 替代工具
    dust # du
    duf # df
    procs # ps
    sd # sed
    jq # JSON
    yq # YAML
    wget

    # 系统信息
    fastfetch
    tealdeer # tldr

    # 文件管理
    gomi
    ouch # 压缩/解压

    # Nix 工具
    nix-output-monitor # nom
    nvd # Nix 版本对比
    nh # Nix 辅助工具
    just

    # AI 编程代理
    inputs.opencode.packages.${pkgs.system}.default
    comment-checker
    skills

    # 其他
    ffmpeg
    pandoc
  ];

  xdg.enable = true;
}

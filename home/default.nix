{
  inputs,
  username,
  pkgs,
  config,
  lib,
  system,
  ...
}:

{
  imports = [
    inputs.catppuccin.homeModules.catppuccin
    ./shell
    ./dev
  ]
  # 桌面角色的 home 层：只在 Linux 导入（Darwin 无 Plasma），内部再按系统实际启用的
  # DE 决定是否生效。换 DE / 加无头机时改 home/desktop，这里不动。
  # 用 system（specialArg）判平台而非 pkgs.stdenv —— 后者依赖 config，用在 imports 会递归。
  ++ lib.optionals (lib.hasSuffix "-linux" system) [ ./desktop ];

  catppuccin = {
    enable = true;
    autoEnable = true;
    flavor = "mocha";
  };

  home = {
    inherit username;
    homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
    stateVersion = "25.11";
  };

  home.packages = with pkgs; [
    duf
    dust
    jq
    procs
    sd
    socat
    wget
    yq

    gomi
    ouch

    just
    nix-output-monitor
    nvd

    ffmpeg
    pandoc
    libredwg # FreeCAD 导入/导出 DWG（提供 dwg2dxf 转换器）

    trzsz-ssh
    tsshd
  ];

  programs.nh = {
    enable = true;
    flake = "${config.home.homeDirectory}/nix-config";
  };

  programs.fastfetch.enable = true;
  programs.tealdeer = {
    enable = true;
    # macOS 上 home-manager 的 tldr-update launchd agent bootstrap 会报 I/O error (code 5)
    # 导致 switch 失败；关掉它，改用 tealdeer 内置的按需自动更新（HM 官方迁移建议）
    enableAutoUpdates = false;
    settings.updates.auto_update = true;
  };

  xdg.enable = true;
}

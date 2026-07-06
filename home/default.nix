{
  inputs,
  username,
  pkgs,
  config,
  lib,
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
    autoEnable = true;
    flavor = "mocha";
  };

  home = {
    username = username;
    homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
    stateVersion = "25.11";
  };

  home.packages = with pkgs; [
    duf
    dust
    jq
    procs
    sd
    wget
    yq

    gomi
    ouch

    just
    nix-output-monitor
    nvd

    comment-checker

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

  # 启用雾凇拼音上游默认配置（nixpkgs 的 rime-ice 把 default.yaml 改名为
  # rime_ice_suggestion.yaml，需在用户配置显式 __include，见 modules/desktop）。
  # 后续 Rime 自定义（按键、候选数等）也加在这份 patch 里。
  xdg.dataFile."fcitx5/rime/default.custom.yaml" = lib.mkIf pkgs.stdenv.isLinux {
    text = ''
      patch:
        __include: rime_ice_suggestion:/
    '';
  };
}

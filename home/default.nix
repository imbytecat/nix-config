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

  # 雾凇拼音需用户侧 default.custom.yaml __include 才有候选（见 docs/adr/0003-wayland-ime-fcitx.md）。
  # 后续 Rime 自定义（按键、候选数等）也加在这份 patch 里。
  xdg.dataFile."fcitx5/rime/default.custom.yaml" = lib.mkIf pkgs.stdenv.isLinux {
    text = ''
      patch:
        __include: rime_ice_suggestion:/
    '';
  };

  # fcitx5 输入法组：默认 IM=rime；home-manager 每 switch 覆盖 ~/.config/fcitx5/profile，新装即成型。
  # 为何走用户路径而非 NixOS ignoreUserConfig，见 docs/adr/0003-wayland-ime-fcitx.md。
  xdg.configFile."fcitx5/profile" = lib.mkIf pkgs.stdenv.isLinux {
    text = lib.generators.toINI { } {
      GroupOrder."0" = "Default";
      "Groups/0" = {
        Name = "Default";
        "Default Layout" = "us";
        DefaultIM = "rime";
      };
      "Groups/0/Items/0".Name = "keyboard-us";
      "Groups/0/Items/1".Name = "rime";
    };
  };
}

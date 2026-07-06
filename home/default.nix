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

  # 启用雾凇拼音上游默认配置（nixpkgs 的 rime-ice 把 default.yaml 改名为
  # rime_ice_suggestion.yaml，需在用户配置显式 __include，见 modules/desktop）。
  # 后续 Rime 自定义（按键、候选数等）也加在这份 patch 里。
  xdg.dataFile."fcitx5/rime/default.custom.yaml" = lib.mkIf pkgs.stdenv.isLinux {
    text = ''
      patch:
        __include: rime_ice_suggestion:/
    '';
  };

  # fcitx5 输入法组（profile）：默认组 Default(us 布局) + 成员 keyboard-us/rime，默认 IM = rime。
  # 声明式 + 可复现：home-manager 每次 switch 用本内容覆盖 ~/.config/fcitx5/profile（旧的进 .bak，
  # 靠 lib 里 backupFileExtension+overwriteBackup），新装即成型，免手动去「系统设置 → 输入法」加 Rime。
  # 走用户路径而非 NixOS 的 ignoreUserConfig：后者设 SKIP_FCITX_USER_PATH 跳过整个用户目录，会连
  # ~/.local/share/fcitx5 一起跳（上面 rime-ice 的 default.custom.yaml 就在那，且 rime 需在该目录
  # 可写以编译方案 build/、userdb），直接弄坏输入法。用户路径保持可写 → 既声明式又不破坏 rime。
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

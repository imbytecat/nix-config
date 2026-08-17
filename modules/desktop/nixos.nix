{
  pkgs,
  lib,
  username,
  ...
}:

let
  # XWayland Qt5 应用需显式 *_IM_MODULE=fcitx。
  wrapWithFcitx =
    pkg: bins:
    pkgs.symlinkJoin {
      name = "${lib.getName pkg}-fcitx5";
      paths = [ pkg ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        for bin in ${lib.concatStringsSep " " bins}; do
          wrapProgram $out/bin/$bin \
            --set QT_IM_MODULE fcitx \
            --set GTK_IM_MODULE fcitx \
            --set XMODIFIERS @im=fcitx
        done
      '';
    };

  wechat-fcitx = wrapWithFcitx pkgs.wechat [ "wechat" ];
  wpsoffice-fcitx = wrapWithFcitx pkgs.wpsoffice-cn [
    "wps"
    "et"
    "wpp"
    "wpspdf"
  ];

in
{
  imports = [ ./fonts.nix ];

  # 不提供 X11 session；XWayland 由 Plasma 自带。
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;
  hardware.graphics.enable = true;

  networking.networkmanager.enable = true;
  # 禁用会探测并抢占 /dev/ttyUSB* 的 ModemManager。
  networking.modemmanager.enable = false;
  users.users.${username}.extraGroups = [
    "networkmanager"
    "dialout"
  ];

  services.printing.enable = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  environment.systemPackages = with pkgs; [
    android-studio
    brave
    cherry-studio
    dbeaver-bin
    discord
    freerdp
    obs-studio
    orca-ide
    qq
    remmina
    snipaste
    spotify
    telegram-desktop
    termius
    ungoogled-chromium
    vlc
    vscode
    wechat-fcitx
    wemeet
    winbox
    wpsoffice-fcitx
  ];

  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ username ];
  };

  # binfmt 让 ./xxx.AppImage 直接执行（单开 binfmt 无效，被 enable 门控）。
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # Solaar 支持该鼠标；libratbag 不支持，故不装 piper。
  programs.solaar.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # rimeDataPkgs 替换默认 rime-data，并补入上游未打包的 LTS .gram。
  # 用户侧 include 与双拼 patch 见 home/desktop/fcitx5.nix。
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        (fcitx5-rime.override {
          rimeDataPkgs = [
            rime-wanxiang
            rime-wanxiang-grammar
          ];
        })
      ];
    };
  };

  # CapsLock 单击触发 fcitx5，按住为 Ctrl，Shift+CapsLock 保留大写锁定。
  # 使用 Hangul，避免 F13 被 evdev 映射为 XF86Tools。
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings = {
        main.capslock = "overload(control, hangeul)";
        shift.capslock = "capslock";
      };
    };
  };
}

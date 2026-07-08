# NixOS 桌面角色：完整 GUI 桌面 = DE + 桌面应用 + 输入法。
# 叠加在 modules/nixos（无头开发 base）之上；无头开发机不导入本文件即可。
# 显卡驱动（nvidia/intel）是硬件属性，放 hosts/<host>/，与桌面角色解耦。
{
  pkgs,
  lib,
  username,
  ...
}:

let
  # XWayland Qt5 应用（微信/WPS，二进制内置 fcitx-qt5）只有显式注入 *_IM_MODULE=fcitx 才加载输入
  # 上下文，故逐入口 wrap。为何不全局设、QQ（Electron）为何不受影响，见 docs/adr/0003-wayland-ime-fcitx.md
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
  # 桌面显示字体（CJK/emoji/UI + fontconfig）独立成块，仅 NixOS 桌面生效
  imports = [ ./fonts.nix ];

  # ── DE: KDE Plasma 6 (Wayland-only) + SDDM ──────────────────
  # 不开 services.xserver.enable：不提供 X11 session，XWayland 由 Plasma 自带
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;
  hardware.graphics.enable = true;

  networking.networkmanager.enable = true;
  users.users.${username}.extraGroups = [ "networkmanager" ];

  # ── 桌面应用（与 desktop/darwin.nix 各自独立演化，互不迁就）──
  environment.systemPackages = with pkgs; [
    android-studio
    brave
    cherry-studio
    dbeaver-bin
    discord
    freecad
    obs-studio
    qq
    spotify
    telegram-desktop
    termius
    ungoogled-chromium
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

  # ── Logitech 外设（替代 macOS 的 G HUB）──────────────────────
  # hardware.logitech.wireless：Unifying/Bolt/Lightspeed 接收器管理（Solaar）
  # PRO X2 SUPERSTRIKE 走 Solaar 即可；libratbag 未收录该鼠标，故不装 piper/ratbagd
  hardware.logitech.wireless = {
    enable = true;
    enableGraphical = true;
  };

  # ── 蓝牙: BlueZ 协议栈；GUI 由 Plasma 6 自带的 bluedevil 托盘提供 ──
  # 与 Logitech 同属桌面外设。硬件已识别(hci0)但 NixOS 默认不起 BlueZ，
  # 需显式开才有 bluetooth.service / bluetoothctl / KDE 蓝牙面板。
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # ── 输入法: Rime + 雾凇拼音(rime-ice)；Plasma 6 走 Wayland 故开 waylandFrontend ──
  # override rimeDataPkgs 整个替换默认 rime-data，只留 rime-ice。rime-ice 需用户侧
  # default.custom.yaml __include 才有候选（见 home/desktop/fcitx5.nix + docs/adr/0003-wayland-ime-fcitx.md）。
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        (fcitx5-rime.override {
          rimeDataPkgs = [ rime-ice ];
        })
      ];
    };
  };
}

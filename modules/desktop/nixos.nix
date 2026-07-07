# NixOS 桌面角色：完整 GUI 桌面 = DE + 桌面应用 + 输入法。
# 叠加在 modules/nixos（无头开发 base）之上；无头开发机不导入本文件即可。
# 显卡驱动（nvidia/intel）是硬件属性，放 hosts/<host>/，与桌面角色解耦。
{
  pkgs,
  username,
  ...
}:

let
  # 微信 4.x（XWayland Qt5，内置 fcitx-qt5）：只有 QT_IM_MODULE=fcitx 才加载输入上下文，故
  # wrap 单独注入 QT/GTK_IM_MODULE + XMODIFIERS。为何不全局设、QQ 为何不受影响，
  # 见 docs/adr/0003-wayland-ime-fcitx.md
  wechat-fcitx = pkgs.symlinkJoin {
    name = "wechat-fcitx5";
    paths = [ pkgs.wechat ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/wechat \
        --set QT_IM_MODULE fcitx \
        --set GTK_IM_MODULE fcitx \
        --set XMODIFIERS @im=fcitx
    '';
  };

  # WPS 同微信（XWayland Qt5，已内置 fcitx5-qt）：四个入口 wps/et/wpp/wpspdf 各 wrap 注入
  # *_IM_MODULE=fcitx 点亮。见 docs/adr/0003-wayland-ime-fcitx.md
  wpsoffice-fcitx = pkgs.symlinkJoin {
    name = "wpsoffice-cn-fcitx5";
    paths = [ pkgs.wpsoffice-cn ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in wps et wpp wpspdf; do
        wrapProgram $out/bin/$bin \
          --set QT_IM_MODULE fcitx \
          --set GTK_IM_MODULE fcitx \
          --set XMODIFIERS @im=fcitx
      done
    '';
  };
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

  # ── 输入法: Rime + 雾凇拼音(rime-ice)；Plasma 6 走 Wayland 故开 waylandFrontend ──
  # override rimeDataPkgs 整个替换默认 rime-data，只留 rime-ice。rime-ice 需用户侧
  # default.custom.yaml __include 才有候选（见 home/default.nix + docs/adr/0003-wayland-ime-fcitx.md）。
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

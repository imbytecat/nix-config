# NixOS 桌面角色：完整 GUI 桌面 = DE + 桌面应用 + 输入法。
# 叠加在 modules/nixos（无头开发 base）之上；无头开发机不导入本文件即可。
# 显卡驱动（nvidia/intel）是硬件属性，放 hosts/<host>/，与桌面角色解耦。
{
  pkgs,
  username,
  ...
}:

let
  # 微信 4.x 是跑在 XWayland 下的 Qt5 应用（二进制内置 fcitx-qt5 插件），Qt 仅当
  # QT_IM_MODULE=fcitx 时才会加载该输入上下文。但本机 waylandFrontend=true 故意不全局
  # 设 *_IM_MODULE（否则原生 Wayland 应用会被拖去走 XIM，见 nixpkgs#278765），而微信自带的
  # AppRun 也不设，于是它连不上 fcitx5 → 微信打不出中文。QQ 是 Electron，靠 --enable-wayland-ime
  # 走 text-input-v3 直连 fcitx5 的 wayland 前端，不需要这些变量，故不受影响。
  # 解法：只给微信单独注入 QT/GTK_IM_MODULE（XMODIFIERS 已全局，带上冗余但无害、自成一体）。
  # 微信外层是 bwrap 且未 --clearenv，环境变量会透传进沙箱；内置 fcitx-qt5 经 $XDG_RUNTIME_DIR
  # 的 DBus 连到 fcitx5。不能全局设是因为那会破坏 waylandFrontend 对原生 Wayland 应用的意义。
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
    feishu
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
  # override rimeDataPkgs 会整个替换默认 rime-data，rime-ice 自带完整方案数据故只留它。
  # 注意：nixpkgs 的 rime-ice 特意把上游 default.yaml 改名为 rime_ice_suggestion.yaml
  # （避免与其他方案包抢占全局配置），需要用户侧 default.custom.yaml 显式 __include
  # 启用，否则 schema_list 为空、无候选框（nixpkgs#449487）。
  # 该文件由 home-manager 管理：home/default.nix 的 xdg.dataFile。
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

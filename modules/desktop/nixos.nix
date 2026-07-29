# NixOS 桌面角色：完整 GUI 桌面 = DE + 桌面应用 + 输入法。
# 叠加在 modules/nixos（无头开发 base）之上；无头开发机不导入本文件即可。
# 显卡驱动（nvidia/amd/intel）是硬件属性，放 hosts/<host>/，与桌面角色解耦。
{
  pkgs,
  lib,
  username,
  ...
}:

let
  # XWayland Qt5 应用（微信/WPS，二进制内置 fcitx-qt5）只有显式注入 *_IM_MODULE=fcitx 才加载输入
  # 上下文，故逐入口 wrap。
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

  # 万象 LTS 语法模型（.gram）；nixpkgs 不含，自己 fetchurl（见 pkgs/rime-wanxiang-grammar）
  rime-wanxiang-grammar = pkgs.callPackage ../../pkgs/rime-wanxiang-grammar { };

  orca-ide = pkgs.callPackage ../../pkgs/orca-ide { };
in
{
  imports = [ ./fonts.nix ];

  # 不开 services.xserver.enable：不提供 X11 session，XWayland 由 Plasma 自带
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;
  hardware.graphics.enable = true;

  networking.networkmanager.enable = true;
  # networkmanager 默认拉起 ModemManager，它会主动 probe /dev/ttyUSB* 抢占串口并自发 AT 指令，
  # 干扰移远模块调试。本机无 WWAN 需求，直接关掉。
  networking.modemmanager.enable = false;
  # dialout：/dev/ttyUSB* 属 root:dialout 660，串口调试需要
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

  # hardware.logitech.wireless：Unifying/Bolt/Lightspeed 接收器管理（Solaar）
  # PRO X2 SUPERSTRIKE 走 Solaar 即可；libratbag 未收录该鼠标，故不装 piper/ratbagd
  hardware.logitech.wireless = {
    enable = true;
    enableGraphical = true;
  };

  # 与 Logitech 同属桌面外设。硬件已识别(hci0)但 NixOS 默认不起 BlueZ，
  # 需显式开才有 bluetooth.service / bluetoothctl / KDE 蓝牙面板。
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # override rimeDataPkgs 整个替换默认 rime-data：rime-wanxiang 出方案+词库，rime-wanxiang-grammar
  # 补上 nixpkgs 不打包的 LTS 语法模型（整句预测，万象核心）。octagram 已随 nixpkgs librime 默认编入，
  # 靠 FallbackResourceResolver 从共享目录加载 .gram。需用户侧 default.custom.yaml __include +
  # wanxiang.custom.yaml 才成型（小鹤双拼，见 home/desktop/fcitx5.nix）。
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

  # 单击=Hangul（fcitx5 唯一触发键，见 home/desktop/fcitx5.nix；Ctrl+Space 还给应用），
  # 按住=Ctrl，Shift+CapsLock=真大写锁定。选 Hangul 而非 F13：xkb 基础表自带 <HNGL>→Hangul
  # keysym 且无程序占用，而 evdev 规则把 F13 映成 XF86Tools；evdev 层不产生 caps LED/大写状态。
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

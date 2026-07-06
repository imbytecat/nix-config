# NixOS 桌面角色：完整 GUI 桌面 = DE + 桌面应用 + 输入法。
# 叠加在 modules/nixos（无头开发 base）之上；无头开发机不导入本文件即可。
# 显卡驱动（nvidia/intel）是硬件属性，放 hosts/<host>/，与桌面角色解耦。
{
  pkgs,
  username,
  ...
}:

{
  # ── DE: KDE Plasma 6 + SDDM ─────────────────────────────────
  services.xserver.enable = true;
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
    wechat
    wemeet
    winbox
  ];

  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ username ];
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

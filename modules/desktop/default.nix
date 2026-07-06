{
  lib,
  pkgs,
  system,
  username,
  ...
}:

let
  isDarwin = lib.hasSuffix "-darwin" system;
  isLinux = lib.hasSuffix "-linux" system;
in

lib.mkMerge [
  (lib.optionalAttrs isDarwin {
    homebrew.casks = [
      "1password"
      "android-studio"
      "brave-browser"
      "cherry-studio"
      "cyberduck"
      "dbeaver-community"
      "discord"
      "feishu"
      "freecad"
      "ghostty"
      "goooler/repo/fl-clash"
      "imbytecat/tap/doubao-ime"
      "imbytecat/tap/roxy-browser"
      "imbytecat/tap/ugreen-nas"
      "keka"
      "logitech-g-hub"
      "microsoft-excel"
      "microsoft-powerpoint"
      "microsoft-word"
      "moonlight"
      "mos"
      "movist-pro"
      "obs"
      "orbstack"
      "qq"
      "raycast"
      "spotify"
      "tailscale-app"
      "telegram-desktop"
      "tencent-meeting"
      "termius"
      "ungoogled-chromium"
      "uuremote"
      "videofusion"
      "visual-studio-code"
      "wechat"
      "wechatwork"
      "windows-app"
      "winbox"
      "xcodes-app"
    ];

    homebrew.masApps = {
      "iPreview" = 1519213509;
      "Xnip" = 1221250572;
    };
  })

  (lib.optionalAttrs isLinux {
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

    # Rime + 雾凇拼音(rime-ice)；Plasma 6 走 Wayland 故开 waylandFrontend。
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
  })
]

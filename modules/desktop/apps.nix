let
  # 两端都装的同一应用：键是 Homebrew cask，值是 nixpkgs 包名。
  # 带配置、服务或特殊安装要求的应用各有文件：1password.nix、tailscale.nix、shell/ghostty.nix。
  both = {
    brave-browser = "brave";
    dbeaver-community = "dbeaver-bin";
    obs = "obs-studio";
    qq = "qq";
    spotify = "spotify";
    telegram-desktop = "telegram-desktop";
    tencent-meeting = "wemeet";
    termius = "termius";
    ungoogled-chromium = "ungoogled-chromium";
    visual-studio-code = "vscode";
    wechat = "wechat-fcitx";
    winbox = "winbox";
  };
in
{
  aspects.darwin.desktop = {
    homebrew.casks = builtins.attrNames both ++ [
      "cyberduck"
      "goooler/repo/fl-clash"
      "imbytecat/tap/roxy-browser"
      "imbytecat/tap/ugreen-nas"
      "keka"
      "microsoft-excel"
      "microsoft-powerpoint"
      "microsoft-word"
      "moonlight"
      "mos"
      "movist-pro"
      "openmtp"
      "orbstack"
      "raycast"
      "uuremote"
      "videofusion"
      "wechatwork"
      "windows-app"
    ];

    homebrew.masApps = {
      "iPreview" = 1519213509;
      "Xnip" = 1221250572;
    };
  };

  # cask 不把 `code` 链进 PATH（NixOS 的 vscode 包自带），排在工具链路径之后。
  aspects.homeManager.desktop =
    { lib, pkgs, ... }:
    {
      home.sessionPath = lib.mkAfter (
        lib.optional pkgs.stdenv.hostPlatform.isDarwin "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
      );
    };

  aspects.nixos.desktop =
    { pkgs, ... }:
    {
      environment.systemPackages =
        map (name: pkgs.${name}) (builtins.attrValues both)
        ++ (with pkgs; [
          discord
          freerdp
          remmina
          snipaste
          vlc
          wpsoffice-fcitx
        ]);
    };
}

# macOS 桌面角色：GUI 应用（Homebrew casks + Mac App Store）。
# 与 desktop/nixos.nix 各自独立演化，互不迁就 —— brew/MAS 与 nixpkgs
# 的包名、机制、可用性差异太大，强行共享列表得不偿失。
# 单机差异 cask 放 hosts/<host>/default.nix（如 thaw 只在 MacBook Air）。
{
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
}

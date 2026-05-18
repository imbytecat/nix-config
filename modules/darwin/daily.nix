{ ... }:

# 日用 Mac 才需要的 Homebrew GUI 应用 / masApps / 单机 brews & taps。
# Mac mini 转作服务器/写代码机器后不再导入这层，由 hosts/mac-mini/default.nix
# 单独声明自己需要的少量 cask。
# 共享层（homebrew.enable / enableFishIntegration / onActivation 等框架）仍在
# modules/darwin/default.nix。

{
  homebrew = {
    taps = [
      "goooler/repo"
    ];

    brews = [
      "mole" # macOS 清理工具
    ];

    casks = [
      "1password"
      "brave-browser"
      "cherry-studio"
      "chromium"
      "cyberduck"
      "dbeaver-community"
      "discord"
      "feishu"
      "goooler/repo/fl-clash"
      "ghostty"
      "keka"
      "logitech-g-hub"
      "mos"
      "movist-pro"
      "openscad@snapshot"
      "orbstack"
      "qq"
      "raycast"
      "spotify"
      "tailscale-app"
      "telegram-desktop"
      "tencent-meeting"
      "termius"
      "uuremote"
      "visual-studio-code"
      "wechat"
      "winbox"
    ];

    masApps = {
      "iPreview" = 1519213509;
      "Microsoft Word" = 462054704;
      "Microsoft Excel" = 462058435;
      "Microsoft PowerPoint" = 462062816;
      "Windows App" = 1295203466;
      "Xnip" = 1221250572;
    };
  };
}

{ ... }:

{
  homebrew = {
    taps = [
      "goooler/repo"
    ];

    brews = [
      "mole" # macOS 清理工具
    ];

    casks = [
      "brave-browser"
      "cherry-studio"
      "dbeaver-community"
      "discord"
      "feishu"
      "goooler/repo/fl-clash"
      "logitech-g-hub"
      "movist-pro"
      "openscad@snapshot"
      "qq"
      "spotify"
      "telegram-desktop"
      "tencent-meeting"
      "termius"
      "wechat"
      "windows-app" # 远程桌面，原 microsoft-remote-desktop 已改名
      "winbox"
    ];

    masApps = {
      "iPreview" = 1519213509;
      "Xnip" = 1221250572;
    };
  };
}

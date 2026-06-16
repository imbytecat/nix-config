{
  pkgs,
  inputs,
  username,
  sshKeys,
  ...
}:

{
  imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

  # 声明式 pin Homebrew + tap 仓库到 flake input commit,brew update 不再悄悄漂移。
  # autoMigrate=true: 新机器自动装 brew,已有 brew 接管;无需手工跑官方 install.sh。
  # mutableTaps=false: tap 只能在 flake 改,`brew tap` 命令禁用。
  nix-homebrew = {
    enable = true;
    user = username;
    enableRosetta = true;
    autoMigrate = true;
    mutableTaps = false;
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "goooler/homebrew-repo" = inputs.homebrew-goooler;
      "imbytecat/homebrew-tap" = inputs.homebrew-imbytecat;
    };
  };

  system.primaryUser = username;

  security.sudo.extraConfig = ''
    ${username} ALL=(ALL) NOPASSWD:ALL
  '';

  security.pam.services.sudo_local.touchIdAuth = true;

  system.startup.chime = false;

  # SMB 客户端调优(挂载时读取,改完需重新挂载共享才生效)
  # 仅保留 Apple 官方明确推荐的项,详见 https://support.apple.com/en-us/102050
  # - protocol_vers_map=6: 只用 SMB2+SMB3,禁掉对老旧不安全 SMB1 的回退
  # - port445=no_netbios: 禁 NetBIOS,关闭 139 端口与 SMB1 回退路径
  # - mc_prefer_wired=yes: 多通道时优先有线网卡(MacBook Air 有 Wi-Fi 时受益)
  # 不再写 signing_required(默认就是 no)、dir_cache_*(Apple 不推荐拉长缓存)
  environment.etc."nsmb.conf".text = ''
    [default]
    protocol_vers_map=6
    port445=no_netbios
    mc_prefer_wired=yes
  '';

  users.knownUsers = [ username ];
  users.users.${username} = {
    home = "/Users/${username}";
    shell = pkgs.fish;
    uid = 501;
    openssh.authorizedKeys.keys = sshKeys;
  };

  system.defaults = {
    LaunchServices.LSQuarantine = false;
    dock = {
      autohide = false;
      show-recents = false;
      mru-spaces = false;
      wvous-tl-corner = 1;
      wvous-tr-corner = 1;
      wvous-bl-corner = 1;
      wvous-br-corner = 1;
    };
    finder = {
      AppleShowAllFiles = true;
      FXPreferredViewStyle = "clmv";
      NewWindowTarget = "Home";
    };
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      AppleICUForce24HourTime = true;
    };
    screensaver = {
      askForPassword = false;
      askForPasswordDelay = 0;
    };
    CustomUserPreferences = {
      "ch.sudo.cyberduck" = {
        "donate.reminder.date" = 253402300799000; # 极远的未来
      };
      "com.apple.finder" = {
        WarnOnEmptyTrash = false;
      };
      # 不在网络共享(SMB/NFS)上写 .DS_Store,减少 Finder 浏览/拷贝时的元数据往返
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
      };
      # CapsLock 切换中英输入法（0=切换大小写，1=切到 ABC）
      "NSGlobalDomain" = {
        TISRomanSwitchState = 1;
        CGDisableCursorLocationMagnification = true;
      };
      # Raycast 接管 ⌘Space（下面 activation 会把 Spotlight 那两个快捷键关掉）
      "com.raycast.macos".raycastGlobalHotkey = "Command-49";
    };
  };

  # screensaver.idleTime 只读 per-host domain，用 -currentHost 兜底
  system.activationScripts.postActivation.text = ''
    user_uid="$(id -u -- ${username})"

    launchctl asuser "$user_uid" sudo --user=${username} -- \
      defaults -currentHost write com.apple.screensaver idleTime -int 0

    # 关 Spotlight 两个快捷键：64=⌘Space (Spotlight)、65=⌥⌘Space (Finder 搜索窗口)。
    # 必须 -dict-add 改单个 key，整体写会覆盖系统默认的几百条快捷键映射。
    launchctl asuser "$user_uid" sudo --user=${username} -- \
      defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 '<dict><key>enabled</key><false/></dict>'
    launchctl asuser "$user_uid" sudo --user=${username} -- \
      defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 65 '<dict><key>enabled</key><false/></dict>'
    launchctl asuser "$user_uid" sudo --user=${username} -- \
      /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  '';

  homebrew = {
    enable = true;
    enableFishIntegration = true;
    greedyCasks = true;

    # 列全 nix-homebrew 管的所有 tap,否则 cleanup="zap" 会尝试 untap
    # 被符号链接的官方 tap。nix-homebrew pin 的 brew 5.1.14 还没引入 trust 强制,
    # 所以不需要 trusted=true 字段(若日后升 brew-src 到 5.1.15+ 再加回来,
    # 见上游 https://github.com/nix-darwin/nix-darwin/pull/1789)
    taps = [
      "homebrew/homebrew-core"
      "homebrew/homebrew-cask"
      "goooler/repo"
      "imbytecat/tap"
    ];

    brews = [
      "mole" # macOS 清理工具
    ];

    casks = [
      "1password"
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
      "visual-studio-code"
      "wechat"
      "wechatwork"
      "windows-app"
      "winbox"
    ];

    masApps = {
      "iPreview" = 1519213509;
      "Xnip" = 1221250572;
    };

    onActivation = {
      # nix-homebrew pin 了 brew 版本,关 autoUpdate 防止运行时 git pull 漂移
      autoUpdate = false;
      upgrade = true;
      cleanup = "zap";
    };
  };
}

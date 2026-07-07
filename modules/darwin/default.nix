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

  # SMB 客户端调优（挂载时读取，改完需重挂共享）。仅留 Apple 官方推荐项（support.apple.com/en-us/102050）：
  # protocol_vers_map=6 只用 SMB2/3、port445=no_netbios 禁 NetBIOS/SMB1、mc_prefer_wired 多通道优先有线。
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
      FXPreferredViewStyle = "Nlsv";
      NewWindowTarget = "Home";
    };
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      AppleICUForce24HourTime = true;
    };
    ".GlobalPreferences"."com.apple.mouse.scaling" = 1.0;
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
      "NSGlobalDomain" = {
        # CapsLock 切换中英输入法（0=切换大小写，1=切到 ABC）
        TISRomanSwitchState = 1;
        CGDisableCursorLocationMagnification = true;
        "com.apple.mouse.linear" = true; # true=关闭鼠标加速度
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

    # 列全 nix-homebrew 管的所有 tap，否则 cleanup="zap" 会 untap 符号链接的官方 tap。
    # 非官方 tap 需 trusted=true（brew 6.0 HOMEBREW_REQUIRE_TAP_TRUST）；官方 tap 永远受信。
    taps = [
      "homebrew/homebrew-core"
      "homebrew/homebrew-cask"
      {
        name = "goooler/repo";
        trusted = true;
      }
      {
        name = "imbytecat/tap";
        trusted = true;
      }
    ];

    brews = [
      "cocoapods"
      "mole"
    ];

    onActivation = {
      # nix-homebrew pin 了 brew 版本,关 autoUpdate 防止运行时 git pull 漂移
      autoUpdate = false;
      upgrade = true;
      cleanup = "zap";
    };
  };
}

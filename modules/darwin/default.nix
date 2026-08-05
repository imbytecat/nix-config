{
  pkgs,
  inputs,
  username,
  sshKeys,
  ...
}:

{
  imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

  # Brew/taps 由 flake pin；自动接管已有安装，禁止命令行新增 tap。
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

  services.openssh.enable = true;

  nix.settings.trusted-users = [ username ];

  security.sudo.extraConfig = ''
    ${username} ALL=(ALL) NOPASSWD:ALL
  '';

  security.pam.services.sudo_local.touchIdAuth = true;

  system.startup.chime = false;

  # Apple 推荐：仅 SMB2/3、禁 NetBIOS、优先有线多通道；改后需重挂。
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
        "donate.reminder.date" = 253402300799000; # 禁用捐赠提醒
      };
      "com.apple.finder" = {
        WarnOnEmptyTrash = false;
      };
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
      };
      "NSGlobalDomain" = {
        # 1 = CapsLock 切到 ABC
        TISRomanSwitchState = 1;
        CGDisableCursorLocationMagnification = true;
        "com.apple.mouse.linear" = true; # 关闭鼠标加速度
      };
      # Raycast 接管 ⌘Space。
      "com.raycast.macos".raycastGlobalHotkey = "Command-49";
    };
  };

  # idleTime 只能写 per-host domain。
  system.activationScripts.postActivation.text = ''
    user_uid="$(id -u -- ${username})"

    launchctl asuser "$user_uid" sudo --user=${username} -- \
      defaults -currentHost write com.apple.screensaver idleTime -int 0

    # 仅改 64/65，避免覆盖整个系统快捷键字典。
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

    # cleanup=zap 要求列全受管 tap；非官方 tap 需 trusted。
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
      # brew 版本已 pin，禁止运行时更新。
      autoUpdate = false;
      upgrade = true;
      cleanup = "zap";
    };
  };
}

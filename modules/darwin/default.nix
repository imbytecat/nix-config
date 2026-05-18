{
  pkgs,
  username,
  sshKeys,
  ...
}:

{
  system.primaryUser = username;

  security.sudo.extraConfig = ''
    ${username} ALL=(ALL) NOPASSWD:ALL
  '';

  security.pam.services.sudo_local.touchIdAuth = true;

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
      FXPreferredViewStyle = "clmv";
      NewWindowTarget = "Home";
    };
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
    };
    screensaver = {
      askForPassword = false;
      askForPasswordDelay = 0;
    };
    CustomUserPreferences = {
      "ch.sudo.cyberduck" = {
        # 把捐赠提示日期设到极远的未来
        "donate.reminder.date" = 253402300799000;
      };
      "com.apple.finder" = {
        WarnOnEmptyTrash = false;
      };
    };
  };

  # screensaver.idleTime 在多数 macOS 上只读 per-host domain，nix-darwin 写
  # 全局 domain 不生效，用 -currentHost 兜底。
  system.activationScripts.postActivation.text = ''
    launchctl asuser "$(id -u -- ${username})" sudo --user=${username} -- \
      defaults -currentHost write com.apple.screensaver idleTime -int 0
  '';

  homebrew = {
    enable = true;
    enableFishIntegration = true;
    greedyCasks = true;

    # 每台 Mac 都要的共同基线；仅日用机用的放 daily.nix，单机用的放 hosts/<host>。
    casks = [
      "1password"
      "ghostty"
      "visual-studio-code"
      "tailscale-app"
      "orbstack"
      "uuremote"
      "chromium"
      "cyberduck"
      "keka"
      "mos"
      "raycast"
    ];

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };
  };
}

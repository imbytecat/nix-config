{
  pkgs,
  username,
  sshKeys,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    curl
    git
    ghostty.terminfo
    docker-compose
  ];

  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [ "en_US.UTF-8/UTF-8" ];
  };
  time.timeZone = "Asia/Shanghai";

  users.users.${username} = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "docker"
    ];
    openssh.authorizedKeys.keys = sshKeys;
  };

  virtualisation.docker.enable = true;

  security.sudo.wheelNeedsPassword = false;

  # 清理 pre-flake 遗留的 root channel symlink
  system.activationScripts.cleanupLegacyChannels.text = ''
    rm -rf /root/.nix-defexpr/channels \
           /root/.nix-defexpr/channels_root \
           /nix/var/nix/profiles/per-user/root/channels \
           /nix/var/nix/profiles/per-user/root/channels-*-link
  '';
}

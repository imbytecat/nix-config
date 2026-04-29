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
    openscad-unstable
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
}

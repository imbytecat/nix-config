{
  pkgs,
  username,
  sshKeys,
  ...
}:

{
  imports = [
    ./docker.nix
  ];

  environment.systemPackages = with pkgs; [
    curl
    git
    ghostty.terminfo
  ];

  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [ "en_US.UTF-8/UTF-8" ];
  };
  time.timeZone = "Asia/Shanghai";

  users.users.${username} = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = sshKeys;
  };

  security.sudo.wheelNeedsPassword = false;
}

{ pkgs, sshKeys, ... }:

{
  imports = [ ./base.nix ];

  environment.systemPackages = [
    pkgs.btop
    pkgs.neovim
    pkgs.ouch
  ];

  fonts.fontconfig.enable = false;

  services.openssh.settings = {
    PermitRootLogin = "prohibit-password";
    PasswordAuthentication = false;
  };
  users.users.root = {
    hashedPassword = "!";
    openssh.authorizedKeys.keys = sshKeys;
  };

  nix.optimise.automatic = true;

}

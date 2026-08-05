{ sshKeys, ... }:

{
  imports = [ ./base.nix ];

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

{ username, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;
  users.users.${username}.extraGroups = [ "networkmanager" ];

  # nix-ld：VSCode Remote / Cursor 等预编译二进制需要动态链接器
  programs.nix-ld.enable = true;

  system.stateVersion = "25.11";
}

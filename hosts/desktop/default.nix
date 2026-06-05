{ username, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # UEFI + systemd-boot：现代 amd64 主板首选。BIOS-only 老机器改 GRUB
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # 桌面机日常网络走 NetworkManager（WiFi/有线随插随用）
  networking.networkmanager.enable = true;
  users.users.${username}.extraGroups = [ "networkmanager" ];

  # nix-ld：VSCode Remote / Cursor 等预编译二进制需要动态链接器
  programs.nix-ld.enable = true;

  system.stateVersion = "25.11";
}

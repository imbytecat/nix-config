{
  lib,
  ...
}:

{
  imports = [
    ../../modules/nixos/qemu-guest.nix
    ./disko.nix
  ];

  nix.settings.substituters = lib.mkBefore [
    "https://mirrors.ustc.edu.cn/nix-channels/store"
  ];

  system.stateVersion = "25.11";

}

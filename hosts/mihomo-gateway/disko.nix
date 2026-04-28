{ lib, ... }:

let
  # nixos-anywhere 前按目标机实际硬件改这里，或在引用处 mkForce 覆盖
  diskDevice = "/dev/sda";
in
{
  disko.devices.disk.main = {
    device = lib.mkDefault diskDevice;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}

{ lib, ... }:

let
  # nixos-anywhere 前先用 lsblk 确认目标盘；后续可替换成 /dev/disk/by-id/...
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

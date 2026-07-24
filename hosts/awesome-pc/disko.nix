{ lib, ... }:

let
  diskDevice = "/dev/disk/by-id/nvme-HS-SSD-C2000Pro_1024G_AA000000000000001070";
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

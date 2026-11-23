{ lib, ... }:

{
  disko.devices = {
    disk =
      lib.genAttrs
        [
          "nvme0n1"
          "nvme1n1"
        ]
        (disk: {
          type = "disk";
          device = "/dev/${disk}";
          content = {
            type = "gpt";
            partitions = {
              BIOS = {
                size = "1M";
                type = "EF02";
              };
              ESP = {
                size = "512M";
                type = "EF00";
                content = {
                  type = "mdraid";
                  name = "efi";
                };
              };
              boot = {
                size = "2G";
                content = {
                  type = "mdraid";
                  name = "boot";
                };
              };
              root = {
                size = "100%";
                content = {
                  type = "mdraid";
                  name = "root";
                };
              };
            };
          };
        });

    mdadm = {
      efi = {
        type = "mdadm";
        level = 1;
        metadata = "1.0";
        content = {
          type = "filesystem";
          format = "vfat";
          mountpoint = "/boot/efi";
          mountOptions = [ "umask=0077" ];
        };
      };
      boot = {
        type = "mdadm";
        level = 1;
        metadata = "1.2";
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/boot";
        };
      };
      # 只有 root 是 RAID0，坏任一块盘即整机重装；ESP 与 /boot 沿用 RAID1，固件从哪块盘都能引导。
      root = {
        type = "mdadm";
        level = 0;
        metadata = "1.2";
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/";
        };
      };
    };
  };
}

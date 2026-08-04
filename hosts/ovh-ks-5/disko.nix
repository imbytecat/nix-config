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
                size = "1G";
                type = "EF00";
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
      boot = {
        type = "mdadm";
        level = 1;
        metadata = "1.0";
        content = {
          type = "filesystem";
          format = "vfat";
          mountpoint = "/boot";
          mountOptions = [ "umask=0077" ];
        };
      };
      root = {
        type = "mdadm";
        level = 1;
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

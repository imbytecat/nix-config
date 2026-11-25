{
  # 两块 NVMe 的 md RAID 机器：ESP 与 /boot 恒为 RAID1，任一块盘都能被固件引导；root 默认 RAID1，host 可改级别。
  aspects.nixos.grub-raid =
    { lib, pkgs, ... }:
    {
      boot.loader = {
        grub = {
          enable = true;
          efiSupport = true;
          efiInstallAsRemovable = true;
          configurationLimit = 10;
        };
        efi = {
          canTouchEfiVariables = false;
          efiSysMountPoint = "/boot/efi";
        };
      };

      # 没有 MAILADDR 或 PROGRAM 时 mdmon 会崩溃；只写日志。
      boot.swraid.mdadmConf = "PROGRAM ${pkgs.util-linux}/bin/logger";

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
          # metadata 1.0 把超级块放在分区末尾，固件看到的仍是普通 FAT。
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
          root = {
            type = "mdadm";
            level = lib.mkDefault 1;
            metadata = "1.2";
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

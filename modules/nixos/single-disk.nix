{
  # 单盘 GPT：ESP 挂在 /boot（systemd-boot 的默认位置），其余给 ext4 根分区。设备与 ESP 大小由 host 决定。
  aspects.nixos.single-disk =
    { lib, ... }:
    {
      disko.devices.disk.main = {
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = lib.mkDefault "512M";
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
    };
}

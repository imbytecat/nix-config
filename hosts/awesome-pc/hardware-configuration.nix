# 占位文件 —— 装机时用以下命令的输出覆盖：
#   sudo nixos-generate-config --root /mnt --show-hardware-config > hardware-configuration.nix
# 生成内容包含 fileSystems / boot.initrd / kernel modules，缺一不可，
# 缺了 evaluation 会失败（fileSystems."/" is required）。
{ ... }:

{
}

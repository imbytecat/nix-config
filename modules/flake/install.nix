# 首装与远程安装用的工具链，由 justfile 的 install 配方和 Live 环境调用。
{ inputs, ... }:

{
  perSystem =
    {
      lib,
      pkgs,
      system,
      ...
    }:
    let
      # 上游 package.nix 仍读取 stdenv.isDarwin；修复后恢复直接 inherit。
      disko-install =
        (inputs.disko.packages.${system}.disko.override {
          stdenv = pkgs.stdenv // {
            isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
          };
        }).overrideAttrs
          (_old: {
            name = "disko-install";
          });
    in
    {
      packages = {
        inherit disko-install;
        inherit (inputs.nixos-anywhere.packages.${system}) nixos-anywhere;

        # 只用来让目标机先跑起带 Nix 的环境，内核无所谓（不碰磁盘）。release 资产会被上游
        # 重建覆盖，hash 不符照 got 更新即可。
        kexec-bootstrap = pkgs.fetchurl {
          url = "https://github.com/nix-community/nixos-images/releases/download/nixos-26.05/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz";
          hash = "sha256-aszcR69v6ePC8bGANc3uh9WMh8BfEw4v5jE0tIhCFrw=";
        };
      }
      // lib.optionalAttrs (system == "x86_64-linux") {
        # 真正分区安装的环境：建 md 阵列的内核必须和目标一致。上游镜像跟最新内核
        # （installer.nix 引入 latest-zfs-kernel.nix），≥6.19 建的阵列带 logical_block_size，6.18 拒绝组装。
        kexec-installer =
          let
            images = inputs.nixos-images;
            # 上游仍写着已移除的 boot.initrd.systemd.enable（scripted initrd 已删），只取它的 initrd 服务。
            restoreAccess = "${images}/nix/restore-remote-access.nix";
          in
          (inputs.nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              "${images}/nix/kexec-installer/module.nix"
              "${images}/nix/noninteractive.nix"
              (
                { lib, pkgs, ... }:
                {
                  disabledModules = [ restoreAccess ];
                  boot.initrd.systemd.services = (import restoreAccess).boot.initrd.systemd.services;
                  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;
                }
              )
            ];
          }).config.system.build.kexecInstallerTarball;
      };
    };
}

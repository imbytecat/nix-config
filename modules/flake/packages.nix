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

        # release 分支资产会被上游重建并重新上传，hash 会随之变化，报 mismatch 就照 got 更新。
        kexec-installer = pkgs.fetchurl {
          url = "https://github.com/nix-community/nixos-images/releases/download/nixos-26.05/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz";
          hash = "sha256-Sk25JC9Hs1ItqLEzHwS7mKi0HG8HSisbxbluWQmv1Bg=";
        };
      }
      // lib.optionalAttrs (system == "x86_64-linux") {
        herdr-app = inputs.llm-agents.packages.${system}.herdr-app;
        wowtype = inputs.wowtype.packages.${system}.default;
      };
    };
}

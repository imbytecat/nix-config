{ inputs, ... }:

{
  perSystem =
    { pkgs, ... }:
    let
      treefmt = inputs.treefmt-nix.lib.evalModule pkgs ../../treefmt.nix;
    in
    {
      formatter = treefmt.config.build.wrapper;

      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.actionlint
          pkgs.just
          pkgs.nixd
          # .vscode 里 nixd 格式化调用裸 nixfmt；取 treefmt 的同一份，保存结果与 nix fmt 一致。
          treefmt.config.programs.nixfmt.package
          pkgs.statix
          pkgs.deadnix
          pkgs.nvd
          pkgs.nix-tree
          treefmt.config.build.wrapper
        ];
      };

      checks = {
        formatting = treefmt.config.build.check inputs.self;

        lint =
          pkgs.runCommand "lint"
            {
              nativeBuildInputs = [
                pkgs.actionlint
                pkgs.statix
                pkgs.deadnix
              ];
            }
            ''
              cd ${inputs.self}
              actionlint .github/workflows/*.yml
              statix check
              # hardware-configuration.nix 由 nixos-generate-config 生成，不由我们维护
              deadnix --fail --exclude \
                ./hosts/awesome-pc/hardware-configuration.nix \
                ./hosts/ovh-ks-5/hardware-configuration.nix
              touch $out
            '';
      };
    };
}

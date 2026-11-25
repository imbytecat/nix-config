{ inputs, ... }:

{
  perSystem =
    { lib, pkgs, ... }:
    let
      treefmt = inputs.treefmt-nix.lib.evalModule pkgs ../../treefmt.nix;
      # scripts/lint.sh 用到的工具；devShell 与 checks.lint 共用这一份。
      linters = with pkgs; [
        actionlint
        deadnix
        ruff
        shellcheck
        statix
      ];
    in
    {
      formatter = treefmt.config.build.wrapper;

      devShells.default = pkgs.mkShell {
        SOPS_AGE_KEY_CMD = lib.getExe (
          pkgs.writeShellApplication {
            name = "sops-ssh-identity";
            runtimeInputs = [ pkgs.ssh-to-age ];
            text = ''exec ssh-to-age -private-key -i "$HOME/.ssh/id_ed25519"'';
          }
        );
        packages = linters ++ [
          pkgs.just
          pkgs.sops
          pkgs.ssh-to-age
          pkgs.nixd
          # .vscode 里 nixd 格式化调用裸 nixfmt；取 treefmt 的同一份，保存结果与 nix fmt 一致。
          treefmt.config.programs.nixfmt.package
          pkgs.nvd
          pkgs.nix-tree
          treefmt.config.build.wrapper
        ];
      };

      checks = {
        formatting = treefmt.config.build.check inputs.self;

        lint = pkgs.runCommand "lint" { nativeBuildInputs = linters; } ''
          cd ${inputs.self}
          bash scripts/lint.sh
          touch $out
        '';
      };
    };
}

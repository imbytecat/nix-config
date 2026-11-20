{
  aspects.darwin.base =
    { inputs, username, ... }:
    {
      imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

      # Brew/taps 由 flake pin；自动接管已有安装，禁止命令行新增 tap。
      nix-homebrew = {
        enable = true;
        user = username;
        enableRosetta = true;
        autoMigrate = true;
        mutableTaps = false;
        taps = {
          "homebrew/homebrew-core" = inputs.homebrew-core;
          "homebrew/homebrew-cask" = inputs.homebrew-cask;
          "goooler/homebrew-repo" = inputs.homebrew-goooler;
          "imbytecat/homebrew-tap" = inputs.homebrew-imbytecat;
        };
      };

      homebrew = {
        enable = true;
        greedyCasks = true;

        # cleanup=zap 要求列全受管 tap；非官方 tap 需 trusted。
        taps = [
          "homebrew/homebrew-core"
          "homebrew/homebrew-cask"
          {
            name = "goooler/repo";
            trusted = true;
          }
          {
            name = "imbytecat/tap";
            trusted = true;
          }
        ];

        brews = [
          "cocoapods"
          "mole"
        ];

        onActivation = {
          # brew 版本已 pin，禁止运行时更新。
          autoUpdate = false;
          upgrade = true;
          cleanup = "zap";
        };
      };
    };
}

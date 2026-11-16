{ config, ... }:

let
  integration =
    { inputs, username, ... }:
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "bak";
        overwriteBackup = true;
        extraSpecialArgs = { inherit inputs username; };
        users.${username}.imports = [ config.aspects.homeManager.daily ];
      };
    };
in
{
  aspects.nixos.daily =
    { inputs, ... }:
    {
      imports = [
        inputs.home-manager.nixosModules.home-manager
        integration
      ];
    };

  aspects.darwin.daily =
    { inputs, ... }:
    {
      imports = [
        inputs.home-manager.darwinModules.home-manager
        integration
      ];
    };

  aspects.homeManager.daily =
    {
      config,
      pkgs,
      username,
      ...
    }:
    {
      home = {
        inherit username;
        homeDirectory =
          if pkgs.stdenv.hostPlatform.isDarwin then "/Users/${username}" else "/home/${username}";
        stateVersion = "26.05";
      };

      home.packages = with pkgs; [
        duf
        dust
        jq
        procs
        sd
        socat
        wget
        yq

        gomi
        ouch

        just
        nix-output-monitor
        nvd

        ffmpeg
        pandoc
        libredwg # FreeCAD DWG

        trzsz-ssh
        tsshd
      ];

      programs.nh = {
        enable = true;
        flake = "${config.home.homeDirectory}/nix-config";
      };

      programs.fastfetch.enable = true;
      programs.tealdeer = {
        enable = true;
        # Darwin 的 tldr-update launchd 会以 code 5 失败，改用按需更新。
        enableAutoUpdates = false;
        settings.updates.auto_update = true;
      };

      xdg.enable = true;
    };
}

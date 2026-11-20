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
        dust
        jq
        sd
        socat
        wget
        yq

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

      programs.fastfetch.enable = true;

      xdg.enable = true;
    };
}

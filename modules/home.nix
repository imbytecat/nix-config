{ config, inputs, ... }:

let
  inherit (config) aspects;
  integration.home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
  };

  dailyUser =
    { username, ... }:
    {
      home-manager = {
        backupFileExtension = "bak";
        overwriteBackup = true;
        extraSpecialArgs = { inherit username; };
        users.${username}.imports = [ aspects.homeManager.daily ];
      };
    };

  desktopUser =
    { username, ... }:
    {
      home-manager.users.${username}.imports = [ aspects.homeManager.desktop ];
    };
in
{
  aspects.nixos.daily.imports = [
    inputs.home-manager.nixosModules.home-manager
    integration
    dailyUser
  ];

  aspects.darwin.daily.imports = [
    inputs.home-manager.darwinModules.home-manager
    integration
    dailyUser
  ];

  aspects.nixos.desktop = desktopUser;
  aspects.darwin.desktop = desktopUser;

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

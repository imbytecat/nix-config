{ config, inputs, ... }:

let
  inherit (config) aspects;
  integration.home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
  };

  workstationUser =
    { username, ... }:
    {
      home-manager = {
        backupFileExtension = "bak";
        overwriteBackup = true;
        extraSpecialArgs = { inherit username; };
        users.${username}.imports = [ aspects.homeManager.workstation ];
      };
    };

  desktopUser =
    { username, ... }:
    {
      home-manager.users.${username}.imports = [ aspects.homeManager.desktop ];
    };
in
{
  aspects.nixos.workstation.imports = [
    inputs.home-manager.nixosModules.home-manager
    integration
    workstationUser
  ];

  aspects.darwin.workstation.imports = [
    inputs.home-manager.darwinModules.home-manager
    integration
    workstationUser
  ];

  aspects.nixos.desktop = desktopUser;
  aspects.darwin.desktop = desktopUser;

  aspects.homeManager.workstation =
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

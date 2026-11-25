{ config, inputs, ... }:

let
  inherit (config) aspects;
  integration.home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
  };

  workstationUser =
    {
      lib,
      pkgs,
      username,
      ...
    }:
    {
      home-manager = {
        # 配置以 Nix 为准：与托管文件冲突的已有文件直接删除再链接，不留 .bak。
        backupCommand = "${lib.getExe' pkgs.coreutils "rm"} -f";
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

  # username 与 homeDirectory 由 HM 的 OS 集成从 users.users 推导。
  aspects.homeManager.workstation = {
    home.stateVersion = "26.05";
    xdg.enable = true;
  };
}

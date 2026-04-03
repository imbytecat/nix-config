{
  description = "NixOS 声明式系统配置";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-wsl,
      home-manager,
      ...
    }:
    let
      system = "x86_64-linux";

      # 所有主机共享的模块
      commonModules = [
        ./modules/base.nix
        ./modules/dev.nix
        ./modules/docker.nix
        ./modules/locale.nix
        ./modules/shell.nix
        home-manager.nixosModules.home-manager
      ];
    in
    {
      nixosConfigurations = {
        # WSL 配置
        wsl = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ [
            nixos-wsl.nixosModules.default
            ./hosts/wsl/default.nix
          ];
        };

        # 裸机配置
        bare = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = commonModules ++ [
            ./hosts/bare/default.nix
          ];
        };
      };
    };
}

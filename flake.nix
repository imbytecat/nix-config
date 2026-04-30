{
  description = "Multi-platform Nix configuration — nix-darwin / NixOS-WSL";

  inputs = {
    # 主 nixpkgs 给 NixOS（WSL/gateway）用，跟 NixOS 集成测试推进
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # darwin 单独 follow nixpkgs-unstable：推进条件更宽松，aarch64-darwin 命中率高于 nixos-unstable
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # AI coding agents (opencode, skills, ...)，每天构建并 push 到 cache.numtide.com
    # 故意不 follows nixpkgs，否则 binary cache 就 miss 了
    llm-agents.url = "github:numtide/llm-agents.nix";

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lazyvim = {
      url = "github:pfassina/lazyvim-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
    let
      mylib = import ./lib { inherit inputs; };
    in
    {
      darwinConfigurations = {
        mac-mini = mylib.mkDarwin {
          hostname = "awesome-mac-mini";
          system = "aarch64-darwin";
          username = "imbytecat";
          extraModules = [ ./hosts/mac-mini ];
        };

        macbook-air = mylib.mkDarwin {
          hostname = "awesome-macbook-air";
          system = "aarch64-darwin";
          username = "imbytecat";
          extraModules = [ ./hosts/macbook-air ];
        };
      };

      nixosConfigurations = {
        wsl = mylib.mkNixos {
          hostname = "awesome-wsl";
          system = "x86_64-linux";
          username = "imbytecat";
          extraModules = [
            inputs.nixos-wsl.nixosModules.default
            ./hosts/wsl
          ];
        };

        gateway = mylib.mkServer {
          hostname = "mihomo-gateway";
          extraModules = [
            ./modules/gateway
            ./hosts/mihomo-gateway
          ];
        };
      };

      packages = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ] (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in
        {
          inherit (pkgs) comment-checker;
        }
      );

      overlays.default = import ./overlays { inherit inputs; };
    };
}

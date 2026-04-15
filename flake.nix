{
  description = "Multi-platform Nix configuration — nix-darwin / NixOS-WSL";

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

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lazyvim.url = "github:pfassina/lazyvim-nix";
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
      # ── macOS 主机 ──────────────────────────────────────
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

      # ── NixOS 主机（Windows PC 上的 WSL）──────────────
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
      };

      # ── 自定义包 ─────────────────────────────────────────
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

      # ── Overlays ───────────────────────────────────────
      overlays.default = import ./overlays;
    };
}

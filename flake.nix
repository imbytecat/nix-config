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

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
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
      # ── macOS hosts ─────────────────────────────────────
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

      # ── NixOS hosts (WSL on Windows PC) ─────────────────
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

      # ── Packages ────────────────────────────────────────
      packages = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ] (system: {
        comment-checker =
          (import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          }).comment-checker;
      });

      # ── Overlays ───────────────────────────────────────
      overlays.default = import ./overlays;
    };
}

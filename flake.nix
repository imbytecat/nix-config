{
  description = "Multi-platform Nix configuration — NixOS / nix-darwin / standalone Home Manager";

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
      # ── NixOS hosts ────────────────────────────────────
      nixosConfigurations = {
        wsl = mylib.mkNixos {
          hostname = "nixos-wsl";
          system = "x86_64-linux";
          username = "dev";
          extraModules = [
            inputs.nixos-wsl.nixosModules.default
            ./hosts/wsl
          ];
        };

        bare = mylib.mkNixos {
          hostname = "nixos";
          system = "x86_64-linux";
          username = "dev";
          extraModules = [ ./hosts/bare ];
        };
      };

      # ── macOS hosts (uncomment when ready) ─────────────
      # darwinConfigurations = {
      #   macbook = mylib.mkDarwin {
      #     hostname = "macbook";
      #     system = "aarch64-darwin";
      #     username = "imbytecat";
      #     extraModules = [ ./hosts/macbook ];
      #   };
      # };

      # ── Standalone Home Manager (non-NixOS / non-Darwin) ─
      homeConfigurations = {
        "dev" = mylib.mkHome {
          system = "x86_64-linux";
          username = "dev";
        };
      };

      # ── Packages ────────────────────────────────────────
      packages = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ] (system: {
        comment-checker = (import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        }).comment-checker;
      });

      # ── Overlays ───────────────────────────────────────
      overlays.default = import ./overlays;
    };
}

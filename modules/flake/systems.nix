{ config, inputs, ... }:

{
  systems = [
    "aarch64-darwin"
    "x86_64-linux"
  ];

  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [ config.flake.overlays.default ];
      };
    };
}

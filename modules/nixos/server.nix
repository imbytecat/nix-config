{
  aspects.nixos.server =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.btop
        pkgs.neovim
        pkgs.ouch
      ];
    };
}

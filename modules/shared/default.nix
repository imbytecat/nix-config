{
  imports = [
    ./fonts.nix
    ./nix.nix
    ./gc.nix
  ];

  programs.fish.enable = true;
  programs._1password.enable = true;
}

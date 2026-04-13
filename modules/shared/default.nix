{
  imports = [
    ./fonts.nix
    ./nix.nix
  ];

  programs.fish.enable = true;
  services.openssh.enable = true;
}

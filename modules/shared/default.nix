{
  imports = [
    ./fonts.nix
    ./nix.nix
  ];

  programs.fish.enable = true;
  programs._1password.enable = true;
  services.openssh.enable = true;
}

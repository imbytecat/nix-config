{ ... }:

{
  catppuccin = {
    enable = true;
    flavor = "mocha";
    nvim.enable = false; # catppuccin-nvim require check broken in nixpkgs
  };
}

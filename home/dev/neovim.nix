{ inputs, pkgs, ... }:

{
  # catppuccin/nix's nvim package is missing nvimSkipModule for detect_integrations
  # Override with higher priority than mkDefault to fix require check failure
  catppuccin.sources.nvim =
    (inputs.catppuccin.packages.${pkgs.stdenv.hostPlatform.system}.nvim).overrideAttrs
      (old: {
        nvimSkipModule = (old.nvimSkipModule or [ ]) ++ [
          "catppuccin.lib.detect_integrations"
        ];
      });

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withNodeJs = true;
    withPython3 = true;
    withRuby = false;
  };
}

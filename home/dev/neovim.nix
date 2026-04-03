{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withNodeJs = true;
    withPython3 = true;
  };

  # ── Neovim distro configuration ──
  # Option A: LazyVim / NvChad / AstroNvim via xdg.configFile
  #   xdg.configFile."nvim" = {
  #     source = ./nvim-config;
  #     recursive = true;
  #   };
  #
  # Option B: NixVim (fully declarative)
  #   Add to flake.nix inputs:
  #     nixvim.url = "github:nix-community/nixvim";
  #   Then configure here.
}

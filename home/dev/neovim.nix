{ pkgs, ... }:

{
  # Disable catppuccin/nix neovim integration — LazyVim manages its own colorscheme
  catppuccin.nvim.enable = false;

  programs.neovim = {
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  programs.lazyvim = {
    enable = true;

    extras = {
      lang.nix.enable = true;
      lang.go.enable = true;
      lang.typescript.enable = true;
      lang.python.enable = true;
      lang.yaml.enable = true;
      lang.docker.enable = true;
    };

    # Catppuccin Mocha colorscheme (managed by LazyVim, not catppuccin/nix)
    plugins = {
      colorscheme = ''
        return {
          {
            "catppuccin/nvim",
            name = "catppuccin",
            opts = { flavour = "mocha" },
          },
          {
            "LazyVim/LazyVim",
            opts = { colorscheme = "catppuccin" },
          },
        }
      '';
    };
  };
}

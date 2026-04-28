{ ... }:

{
  # LazyVim 自管配色方案，关掉 catppuccin/nix 的 nvim 集成
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

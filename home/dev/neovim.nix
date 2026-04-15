_:

{
  # 禁用 catppuccin/nix 的 Neovim 集成 — LazyVim 自行管理配色方案
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

    # Catppuccin Mocha 配色方案（由 LazyVim 管理，非 catppuccin/nix）
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

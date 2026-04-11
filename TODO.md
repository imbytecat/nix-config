# TODO

## catppuccin-nvim require check workaround

- **文件**: `home/dev/neovim.nix`
- **内容**: 覆盖 `catppuccin.sources.nvim` 补上 `nvimSkipModule`
- **原因**: catppuccin/nix 的 `pkgs/nvim/package.nix` 漏了 `catppuccin.lib.detect_integrations`，该模块依赖 lazy.nvim 运行时，nix 构建沙箱里 require check 必定失败
- **上游**: https://github.com/catppuccin/nix — 需要在 `nvimSkipModule` 列表中添加 `catppuccin.lib.detect_integrations`
- **清理条件**: `nix flake update` 后若 `catppuccin.enable = true` + 删除 neovim.nix 中的 override 仍能 `nix build` 通过，即可移除

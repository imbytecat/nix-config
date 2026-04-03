{ config, pkgs, ... }:

{
  # 系统级启用 Zsh（用户级配置在 home/shell.nix）
  programs.zsh.enable = true;
}

{ lib, username, ... }:

{
  # 移除 NixOS 默认别名（ls/ll/l）— 由 Home Manager eza 管理
  environment.shellAliases = lib.mkForce { };

  wsl = {
    enable = true;
    defaultUser = username;
    interop.register = true;
  };

  # nix-ld：VSCode Remote 等预编译二进制需要动态链接器
  programs.nix-ld.enable = true;

  system.stateVersion = "25.11";
}

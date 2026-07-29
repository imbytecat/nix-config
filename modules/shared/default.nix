{
  imports = [
    ./fonts.nix
    ./nix.nix
  ];

  # 只放跨平台且与角色无关的日用组件。SSH 不在这里：NixOS 由 modules/nixos/base.nix
  # 统一开（服务器也要），Darwin 在 modules/darwin/default.nix 自己开。
  programs.fish.enable = true;
  programs._1password.enable = true;
}

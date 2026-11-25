{ config, ... }:

let
  inherit (config) aspects;
in
{
  # 开发机的 NixOS 部分：日常机经 daily 带上，agent-server 在 hosts.nix 组合。
  aspects.nixos.daily.imports = [ aspects.nixos.agent ];

  aspects.nixos.agent = {
    # mise 的预编译运行时、Android SDK 工具和 VS Code/Cursor Remote 都需要。
    programs.nix-ld.enable = true;
  };
}

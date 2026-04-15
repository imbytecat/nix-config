{ lib, username, ... }:

{
  # ── Shell ─────────────────────────────────────────────
  # 移除 NixOS 默认别名（ls/ll/l）— 由 Home Manager eza 管理
  environment.shellAliases = lib.mkForce { };

  # ── WSL ──────────────────────────────────────────────
  wsl = {
    enable = true;
    defaultUser = username;
    interop.register = true;
  };

  # ── nix-ld (VSCode Remote, etc.) ────────────────────
  programs.nix-ld.enable = true;

  system.stateVersion = "24.11";
}

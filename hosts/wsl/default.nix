{
  lib,
  pkgs,
  options,
  username,
  ...
}:

{
  # ── Shell ─────────────────────────────────────────────
  # Remove NixOS default aliases (ls/ll/l) — managed by Home Manager eza
  environment.shellAliases = lib.mkForce { };

  # ── WSL ──────────────────────────────────────────────
  wsl = {
    enable = true;
    defaultUser = username;
    interop.register = true;
  };

  # ── nix-ld (VSCode Remote, mise, npm, etc.) ─────────
  programs.nix-ld = {
    enable = true;
    libraries =
      options.programs.nix-ld.libraries.default
      ++ (with pkgs; [
        icu
        libcrypt
      ]);
  };

  system.stateVersion = "24.11";
}

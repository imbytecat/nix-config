{ pkgs, ... }:

{
  # ── System-essential packages ──────────────────────
  # User-level tools live in home-manager (home/)
  environment.systemPackages = with pkgs; [
    curl
    git
    vim
    wget
  ];

  # ── Fonts ──────────────────────────────────────────
  fonts.packages = with pkgs; [
    maple-mono.NF-CN-unhinted
    nerd-fonts.symbols-only
  ];
}

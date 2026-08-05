{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    maple-mono.NF-CN-unhinted
    nerd-fonts.symbols-only
  ];
}

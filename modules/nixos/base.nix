{ pkgs, ... }:

{
  imports = [
    ../shared/gc.nix
    ../shared/nix.nix
  ];

  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "Asia/Shanghai";

  # 任一角色落地即用的 CLI 底座；带配置的习惯 daily 走 HM，server 在 server.nix 放交互回声。
  # ghostty.terminfo：日用机终端是 Ghostty，SSH 到任何一台都要认识 TERM。
  environment.systemPackages = with pkgs; [
    curl
    git
    ghostty.terminfo
    lsof
    pciutils
    usbutils
    smartmontools
  ];

  services.openssh.enable = true;

  zramSwap.enable = true;

}

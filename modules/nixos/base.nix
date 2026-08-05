{
  imports = [
    ../shared/gc.nix
    ../shared/nix.nix
  ];

  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "Asia/Shanghai";

  services.openssh.enable = true;

  zramSwap.enable = true;

}

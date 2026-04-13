{
  pkgs,
  username,
  sshKeys,
  ...
}:

{
  imports = [
    ./docker.nix
  ];

  # ── System-essential packages ──────────────────────
  environment.systemPackages = with pkgs; [
    curl
    git
    ghostty.terminfo
  ];

  # ── Locale / Timezone ──────────────────────────────
  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [ "en_US.UTF-8/UTF-8" ];
  };
  time.timeZone = "Asia/Shanghai";

  # ── Default user ───────────────────────────────────
  users.users.${username} = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = sshKeys;
  };

  # ── sudo ───────────────────────────────────────────
  security.sudo.wheelNeedsPassword = false;
}

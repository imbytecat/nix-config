{ lib, pkgs, ... }:

{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
  ];

  system.stateVersion = "26.05";

  boot.swraid.mdadmConf = "PROGRAM ${pkgs.util-linux}/bin/logger";

  networking.useDHCP = true;
  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  users.groups.t3code = { };
  users.users.t3code = {
    isSystemUser = true;
    group = "t3code";
    home = "/var/lib/t3code";
    createHome = true;
    homeMode = "0700";
    shell = pkgs.bashInteractive;
    linger = true;
  };

  home-manager.users.t3code = {
    home.stateVersion = "26.05";
    programs.t3code.server.extraArgs = lib.mkBefore [
      "--host"
      "127.0.0.1"
    ];
    # 空机也能配对，模型密钥另放在服务账号的私有文件里。
    systemd.user.services.t3code.Service.EnvironmentFile = "-%h/.config/t3code/env";
  };
}

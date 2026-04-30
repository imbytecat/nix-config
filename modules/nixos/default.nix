{
  inputs,
  pkgs,
  username,
  sshKeys,
  ...
}:

{
  # NixOS 用 mkNixos builder（无显式 nixpkgs.pkgs），由模块系统按下面的 config/overlays 实例化
  # darwin 走 mkDarwin builder（lib/default.nix 里显式 import nixpkgs-darwin），不来这里
  # gateway 走 mkServer，不导入这个文件
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [ inputs.self.overlays.default ];

  environment.systemPackages = with pkgs; [
    curl
    git
    ghostty.terminfo
    docker-compose
    openscad-unstable
  ];

  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [ "en_US.UTF-8/UTF-8" ];
  };
  time.timeZone = "Asia/Shanghai";

  users.users.${username} = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "docker"
    ];
    openssh.authorizedKeys.keys = sshKeys;
  };

  virtualisation.docker.enable = true;

  security.sudo.wheelNeedsPassword = false;
}

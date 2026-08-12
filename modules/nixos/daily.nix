{
  inputs,
  pkgs,
  username,
  sshKeys,
  ...
}:

{
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [ inputs.self.overlays.default ];

  nix.settings.trusted-users = [ username ];

  # 显式 autoEnable 兼容 upstream 26.11 语义，确保系统 ports 真正启用。
  catppuccin = {
    enable = true;
    autoEnable = true;
    flavor = "mocha";
  };

  # 界面保持 en_US，时间与日期使用 zh_CN 的 24 小时格式。
  i18n.extraLocaleSettings.LC_TIME = "zh_CN.UTF-8";

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

  # VS Code/Cursor Remote 等预编译二进制需要。
  programs.nix-ld.enable = true;

  services.tailscale.enable = true;

  security.sudo.wheelNeedsPassword = false;
}

# 日用开发角色：叠在 ./base.nix 之上，GUI 桌面再叠 modules/desktop/nixos.nix。
# 无头开发机（SSH remote dev）到这层为止即可；无头服务器走 ./server.nix，不导入本文件。
{
  inputs,
  pkgs,
  username,
  sshKeys,
  ...
}:

{
  # NixOS 用 mkNixos builder（无显式 nixpkgs.pkgs），由模块系统按下面的 config/overlays 实例化
  # darwin 走 mkDarwin builder（lib/default.nix 里显式 import nixpkgs-unstable），不来这里
  # 服务器走 mkServer，不导入这个文件，闭包里因此没有 unfree 与本仓 overlay
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [ inputs.self.overlays.default ];

  # 日用机的普通用户要能用 flake nixConfig 里的 cache（服务器没有普通用户，见 shared/nix.nix）
  nix.settings.trusted-users = [ username ];

  # 系统层 Catppuccin：flavor 与 home 层（home/default.nix）保持一致。autoEnable 显式写出
  # 而非留默认——upstream 26.11 起把 autoEnable 当作 port 总开关、enable 变全局 kill switch，
  # 不显式设就会 warn；写全后 sddm / tty / fcitx5 / fish 等 system port 才真正上主题。
  catppuccin = {
    enable = true;
    autoEnable = true;
    flavor = "mocha";
  };

  environment.systemPackages = with pkgs; [
    curl
    git
    ghostty.terminfo
    docker-compose
    pciutils
    usbutils
    lsof
    smartmontools
  ];

  # 界面保持 en_US（defaultLocale 在 ./base.nix），时间走 24h 制（Plasma 数字时钟默认跟随
  # region 格式），日期/星期随之中文化（如「星期三」）。想要英文 24h 可换 en_GB 或 en_DK
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

  # nix-ld：VSCode Remote / Cursor 等预编译二进制需要动态链接器。
  # 无头开发场景（SSH remote dev）的基础能力，放 base 而非 host。
  programs.nix-ld.enable = true;

  # Tailscale：无头服务（tailscaled + CLI），所有日用 NixOS 机共享。
  # macOS 走 brew cask tailscale-app（modules/desktop/darwin.nix），gateway 不导入本文件。
  services.tailscale.enable = true;

  security.sudo.wheelNeedsPassword = false;
}

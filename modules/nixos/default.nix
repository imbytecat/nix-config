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
  # gateway 走 mkServer，不导入这个文件
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [ inputs.self.overlays.default ];

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

  i18n = {
    defaultLocale = "en_US.UTF-8";
    # LC_TIME 单独用 zh_CN：界面保持 en_US，时间走 24h 制（Plasma 数字时钟默认跟随 region 格式），
    # 日期/星期随之中文化（如「星期三」）。想要英文 24h 可换 en_GB（欧式日期）或 en_DK（ISO 8601）
    extraLocaleSettings.LC_TIME = "zh_CN.UTF-8";
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

  # nix-ld：VSCode Remote / Cursor 等预编译二进制需要动态链接器。
  # 无头开发场景（SSH remote dev）的基础能力，放 base 而非 host。
  programs.nix-ld.enable = true;

  # Tailscale：无头服务（tailscaled + CLI），所有日用 NixOS 机共享。
  # macOS 走 brew cask tailscale-app（modules/desktop/darwin.nix），gateway 不导入本文件。
  services.tailscale.enable = true;

  security.sudo.wheelNeedsPassword = false;
}

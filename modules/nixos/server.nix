# 无头服务器角色：叠在 ./base.nix 之上，不导入 ./dev.nix / modules/desktop / home-manager，
# 避免日用模块（fish / 1password / docker / catppuccin）污染服务器闭包。
# 只放「任何一台无人值守服务器都成立」的事实；单机硬件与业务放 hosts/<host>/ 与 modules/<purpose>/。
{ sshKeys, ... }:

{
  imports = [ ./base.nix ];

  # 无 GUI：省掉 fontconfig 及其字体闭包
  fonts.fontconfig.enable = false;

  # root-only：不建普通用户，密码登录全关，只认 key
  services.openssh.settings = {
    PermitRootLogin = "prohibit-password";
    PasswordAuthentication = false;
  };
  users.users.root = {
    hashedPassword = "!";
    openssh.authorizedKeys.keys = sshKeys;
  };

  # 无人值守长跑：不回收 store 等于等着根分区被撑满；generation 不设上限迟早塞满 ESP
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;
  boot.loader.systemd-boot.configurationLimit = 10;

  # 服务器多是小内存 VM 且不休眠：压缩内存兜一层 OOM，不占磁盘
  zramSwap.enable = true;
}

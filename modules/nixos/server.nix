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

  # 无人值守长跑：定期合并重复 store path，GC 由跨平台 modules/shared/gc.nix 统一负责
  nix.optimise.automatic = true;

}
